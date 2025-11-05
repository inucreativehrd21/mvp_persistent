"""
vLLM Docker 기반 힌트 생성 시스템
"""
import argparse
import gradio as gr
import json
import time
from typing import List, Dict
from pathlib import Path

from config import Config
from models.model_inference import VLLMInference


class VLLMHintApp:
    """vLLM Docker 전용 힌트 생성 애플리케이션"""

    def __init__(self, data_path: str, vllm_url: str = "http://localhost:8000/v1"):
        self.data_path = data_path
        self.problems = self._load_problems()
        self.vllm_url = vllm_url
        self.current_problem = None
        self.current_problem_id = None
        self.current_model = self._initialize_model()

    def _load_problems(self) -> List[Dict]:
        """문제 데이터 로드"""
        with open(self.data_path, 'r', encoding='utf-8') as f:
            return json.load(f)

    def _initialize_model(self) -> VLLMInference:
        """vLLM 모델 초기화"""
        try:
            model = VLLMInference(
                model_name=Config.VLLM_MODEL,
                base_url=self.vllm_url,
                timeout=60
            )
            print(f"✅ vLLM 서버 연결 성공: {self.vllm_url}")
            return model
        except Exception as e:
            print(f"⚠️  vLLM 서버 연결 실패: {e}")
            print("    docker-compose up으로 서버를 시작하세요.")
            return None

    def get_problem_list(self) -> List[str]:
        """문제 목록 반환"""
        return [
            f"#{p['problem_id']} - {p['title']} (Level {p['level']})"
            for p in self.problems
        ]

    def load_problem(self, problem_selection: str):
        """선택된 문제 로드"""
        if not problem_selection:
            self.current_problem = None
            self.current_problem_id = None
            return "문제를 선택하세요.", "", None, "⚠️ 현재 선택된 문제: 없음"

        try:
            problem_id_str = problem_selection.split('#')[1].split(' -')[0].strip()
            self.current_problem = next(
                (p for p in self.problems if str(p['problem_id']) == problem_id_str),
                None
            )

            if not self.current_problem:
                self.current_problem_id = None
                return "❌ 문제를 찾을 수 없습니다.", "", None, "❌ 문제를 찾을 수 없습니다."

            self.current_problem_id = problem_id_str
            problem_md = self._format_problem_display()
            debug_msg = f"✅ 현재 선택된 문제: `{problem_id_str}`"

            return problem_md, "# 여기에 코드를 작성하세요\n", problem_id_str, debug_msg

        except Exception as e:
            self.current_problem_id = None
            return f"❌ 오류: {str(e)}", "", None, f"❌ 오류: {str(e)}"

    def _format_problem_display(self) -> str:
        """문제 표시 포맷"""
        p = self.current_problem
        md = f"""# {p['title']}

**난이도:** Level {p['level']} | **태그:** {', '.join(p['tags'])}

---

## 문제 설명
{p['description']}

## 입력
{p['input_description']}

## 출력
{p['output_description']}

## 예제
"""
        for i, example in enumerate(p['examples'], 1):
            input_txt = example.get('input', '(없음)')
            output_txt = example.get('output', '(없음)')
            md += f"\n**예제 {i}**\n```\n입력: {input_txt}\n출력: {output_txt}\n```\n"

        return md

    def generate_hint(self, user_code: str, temperature: float, problem_id):
        """힌트 생성"""
        if problem_id is None:
            problem_id = self.current_problem_id

        if problem_id is None:
            return "❌ 먼저 문제를 선택해주세요.", ""

        self.current_problem = next(
            (p for p in self.problems if str(p['problem_id']) == str(problem_id)),
            None
        )

        if not self.current_problem:
            return f"❌ 문제를 찾을 수 없습니다. (ID: {problem_id})", ""

        if not user_code.strip():
            return "❌ 코드를 입력해주세요.", ""

        if not self.current_model:
            return "❌ vLLM 서버에 연결되지 않았습니다. docker-compose up으로 서버를 시작하세요.", ""

        prompt = self._create_hint_prompt(user_code)
        start_time = time.time()

        try:
            result = self.current_model.generate_hint(
                prompt=prompt,
                max_tokens=512,
                temperature=temperature
            )

            elapsed_time = time.time() - start_time

            if result.get('error'):
                return f"❌ 생성 실패: {result['error']}", ""

            hint = result.get('hint', '(빈 응답)')
            metrics = f"""
## 추론 성능
- **소요 시간:** {elapsed_time:.3f}초
- **Temperature:** {temperature}
- **Model:** {self.current_model.model_name}
- **Tokens:** {result.get('tokens', 0)}
"""
            return hint, metrics

        except Exception as e:
            return f"❌ 오류 발생: {str(e)}", ""

    def _create_hint_prompt(self, user_code: str) -> str:
        """Socratic 프롬프트 생성"""
        p = self.current_problem
        solutions = p.get('solutions', [])

        if solutions and solutions[0].get('logic_steps'):
            next_step = solutions[0]['logic_steps'][0].get('goal', '문제 해결')
        else:
            next_step = "문제 해결"

        return f"""당신은 학생의 호기심을 자극하고 스스로 발견하게 만드는 창의적 멘토입니다.

### 학생의 현재 코드:
```python
{user_code}
```

### 핵심 미션:
학생이 다음 단계인 "{next_step}"의 필요성을 **스스로 깨닫고 열망하도록** 만드세요.
직접 답을 주지 말고, 학생의 상상력과 호기심을 폭발시키는 질문을 던지세요.

### 동기 유발 전략:

1. **규모 확장 시나리오**: 데이터가 1000배 늘어나면? 사용자가 100만 명이 되면?
2. **실생활 연결**: 유튜브는 수백만 영상을 어떻게 관리할까?
3. **불편함 자극**: 같은 코드를 100번 복사해야 한다면?
4. **호기심 유발**: 왜 프로 개발자들은 항상 이 패턴을 사용할까?
5. **성취감 예고**: 이것만 해결하면 훨씬 강력해질 텐데

### 절대 금지:
❌ 함수명, 변수명, 코드 키워드 직접 언급
❌ "for 반복문", "if 조건문" 같은 기술 용어
❌ "~를 사용하세요" 같은 직접 지시

### 출력 형식:
단 1개의 질문만 작성하세요. 30-50단어 이내로 간결하면서도 강렬하게.

질문:"""


def create_vllm_ui(app: VLLMHintApp):
    """Gradio UI 생성"""
    with gr.Blocks(title="vLLM Docker 힌트 생성", theme=gr.themes.Soft()) as demo:
        gr.Markdown("# vLLM Docker 기반 힌트 생성 시스템")
        gr.Markdown("Docker로 실행되는 vLLM 서버를 통한 빠른 힌트 생성")

        # 연결 상태
        status_msg = f"✅ **vLLM 서버 연결됨:** `{app.vllm_url}`" if app.current_model else \
                     "⚠️ **vLLM 서버 미연결** - `docker-compose up`으로 서버를 시작하세요!"
        gr.Markdown(status_msg)
        gr.Markdown("---")

        # 문제 선택
        with gr.Row():
            problem_dropdown = gr.Dropdown(
                choices=app.get_problem_list(),
                label="문제 선택",
                interactive=True,
                value=None,
                scale=3
            )
            load_btn = gr.Button("불러오기", variant="primary", scale=1)

        problem_display = gr.Markdown("")
        current_problem_id = gr.State(value=None)
        debug_info = gr.Markdown("⚠️ 현재 선택된 문제: 없음", visible=True)

        gr.Markdown("---")

        # 코드 입력
        gr.Markdown("## 코드 작성")
        user_code = gr.Code(
            label="Python 코드",
            language="python",
            lines=12,
            value="# 여기에 코드를 작성하세요\n"
        )

        # Temperature 조절
        gr.Markdown("### Temperature (창의성 조절)")
        temperature_slider = gr.Slider(
            minimum=0.1,
            maximum=1.0,
            value=0.75,
            step=0.05,
            label="Temperature",
            info="낮을수록 일관적, 높을수록 창의적",
            interactive=True
        )

        hint_btn = gr.Button("힌트 생성", variant="primary", size="lg")

        gr.Markdown("---")

        # 결과
        gr.Markdown("## 생성된 힌트")
        hint_output = gr.Markdown("_힌트가 여기에 표시됩니다_")

        gr.Markdown("---")

        gr.Markdown("## 성능 메트릭")
        metrics_output = gr.Markdown("_추론 성능이 여기에 표시됩니다_")

        # 이벤트 핸들러
        load_btn.click(
            fn=app.load_problem,
            inputs=[problem_dropdown],
            outputs=[problem_display, user_code, current_problem_id, debug_info]
        )

        problem_dropdown.select(
            fn=app.load_problem,
            inputs=[problem_dropdown],
            outputs=[problem_display, user_code, current_problem_id, debug_info]
        )

        hint_btn.click(
            fn=app.generate_hint,
            inputs=[user_code, temperature_slider, current_problem_id],
            outputs=[hint_output, metrics_output]
        )

    return demo


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="vLLM Docker Hint Generation System")
    parser.add_argument("--server-name", type=str, default=None,
                       help="Server host (default: from config)")
    parser.add_argument("--server-port", type=int, default=None,
                       help="Server port (default: from config)")
    parser.add_argument("--share", action="store_true",
                       help="Create public share link")
    args = parser.parse_args()

    print("\n" + "=" * 60)
    print("vLLM Docker 기반 힌트 생성 시스템")
    print("=" * 60 + "\n")

    Config.print_config()

    # 데이터 파일 확인
    DATA_PATH = Config.DATA_FILE_PATH
    if not DATA_PATH.exists():
        print(f"\n❌ 데이터 파일을 찾을 수 없습니다: {DATA_PATH}")
        print("   problems_multi_solution.json을 data/ 디렉토리에 복사하세요.")
        exit(1)

    # 앱 초기화
    print(f"\n문제 데이터 로딩: {DATA_PATH}")
    app = VLLMHintApp(str(DATA_PATH), vllm_url=Config.VLLM_SERVER_URL)
    print(f"✅ {len(app.problems)}개 문제 로드 완료!\n")

    # UI 생성 및 실행
    print("Gradio UI 시작...\n")
    demo = create_vllm_ui(app)

    demo.launch(
        server_port=args.server_port or Config.GRADIO_PORT,
        server_name=args.server_name or Config.GRADIO_HOST,
        share=args.share
    )
