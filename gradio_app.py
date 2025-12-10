"""AETHER Gradio Web Interface"""
import os
import subprocess
import tempfile
import random
import time
from pathlib import Path
import gradio as gr

# 获取项目根目录
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 配置路径（使用绝对路径）
# 优先使用环境变量（适配Docker和Cloud Run），否则使用默认构建路径
SD_CPP_BIN = os.environ.get("SD_CPP_BINARY_PATH", os.path.join(BASE_DIR, "stable-diffusion.cpp/build/bin/sd"))

# 模型路径配置 - 支持 Cloud Run GCS 挂载
MODEL_PATH = os.environ.get("MODEL_PATH", BASE_DIR)
MODEL_FILE = os.path.join(MODEL_PATH, "z_image_turbo-Q4_K_M.gguf")
VAE_FILE = os.path.join(MODEL_PATH, "ae.safetensors")
LLM_FILE = os.path.join(MODEL_PATH, "Qwen3-4B-Q4_K_M.gguf")

# 输出目录
OUTPUT_DIR = os.path.join(BASE_DIR, "output")

# 示例提示词
EXAMPLE_PROMPTS = [
    "一位男士和他的贵宾犬穿着装备参加警戒秀,室内灯光,背景中有观众。",
    "芭芭拉感的暗调人像,一位优雅的中国美女在黑暗的房间里。一束强光透过遮光板,在她身上形成戏剧性的光影效果。",
    "一张中景手机自拍照片拍摄了一位留着长黑发的年轻东亚女子在灯光明亮的电梯内对着镜子自拍。",
    "身着红色汉服的中国年轻女子,汉服上的刺绣精美绝伦。",
    "一幅竖幅数字插画,描绘了一幅宁静而庄严的景象,充满细节和层次感。",
    "一张虚构的英语电影《回忆之味》(The Taste of Memory)的电影海报。场景设置在一个质感的背景中,充满电影感。",
    "一张方形构图的特色照片,主体是一片巨大的、鲜绿色的植物叶片,并上面有文字,设置在一个简洁的白色背景中。"
]

# 分辨率预设
RESOLUTION_PRESETS = {
    "1024": {
        "1024x1024 (1:1)": (1024, 1024),
        "1024x512 (2:1)": (1024, 512),
        "512x1024 (1:2)": (512, 1024),
    },
    "512": {
        "512x512 (1:1)": (512, 512),
        "512x256 (2:1)": (512, 256),
        "256x512 (1:2)": (256, 512),
    },
    "768": {
        "768x768 (1:1)": (768, 768),
        "768x384 (2:1)": (768, 384),
        "384x768 (1:2)": (384, 768),
    }
}


def check_files():
    """检查必需文件是否存在"""
    missing = []
    if not os.path.exists(SD_CPP_BIN):
        missing.append(f"可执行文件: {SD_CPP_BIN}")
    if not os.path.exists(MODEL_FILE):
        missing.append(f"模型文件: {MODEL_FILE}")
    if not os.path.exists(VAE_FILE):
        missing.append(f"VAE文件: {VAE_FILE}")
    return missing


def generate_image(
    prompt: str,
    resolution_category: str,
    resolution: str,
    seed: int,
    random_seed: bool,
    steps: int,
    time_offset: int
):
    """生成图像"""
    # 检查文件
    missing = check_files()
    if missing:
        return None, f"错误: 缺少必需文件:\n" + "\n".join(missing), None
    
    # 解析分辨率
    width, height = RESOLUTION_PRESETS[resolution_category][resolution]
    
    # 处理种子
    if random_seed:
        actual_seed = -1  # sd.cpp使用负数表示随机种子
        display_seed = random.randint(0, 2**31 - 1)
    else:
        actual_seed = int(seed) if seed >= 0 else -1
        display_seed = actual_seed if actual_seed >= 0 else random.randint(0, 2**31 - 1)
    
    # 检查提示词
    if not prompt or not prompt.strip():
        return None, "错误: 请输入提示词", None
    
    # 创建临时输出目录
    output_dir_abs = os.path.abspath(OUTPUT_DIR)
    os.makedirs(output_dir_abs, exist_ok=True)
    timestamp = int(time.time())
    output_file = os.path.join(output_dir_abs, f"output_{timestamp}.png")
    
    # 构建命令
    cmd = [
        SD_CPP_BIN,
        "--diffusion-model", MODEL_FILE,
        "--vae", VAE_FILE,
        "-p", prompt.strip(),
        "--cfg-scale", "1.0",
        "-H", str(height),
        "-W", str(width),
        "--steps", str(steps),
        "-o", output_file,
        "-s", str(actual_seed),
        "--diffusion-fa"
    ]
    
    # AETHER模型需要LLM提供文本编码器
    # 如果LLM文件存在，添加LLM参数
    if os.path.exists(LLM_FILE):
        cmd.extend(["--llm", LLM_FILE])
    
    # 性能优化说明：
    # - macOS上Metal加速会自动启用（编译时已配置）
    # - 不要添加 --offload-to-cpu，这会禁用Metal加速
    # - AETHER优化为8步推理，更多步数不会显著提升质量
    
    try:
        # 执行命令
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,  # 10分钟超时
            cwd=BASE_DIR
        )
        
        # 检查输出文件是否存在
        if os.path.exists(output_file):
            # 读取生成的图像
            return output_file, f"生成成功!\n使用种子: {display_seed}", display_seed
        else:
            error_msg = result.stderr if result.stderr else result.stdout
            return None, f"生成失败:\n{error_msg}", None
            
    except subprocess.TimeoutExpired:
        return None, "错误: 生成超时（超过10分钟）", None
    except Exception as e:
        return None, f"错误: {str(e)}", None


def load_example(example_index: int):
    """加载示例提示词"""
    if 0 <= example_index < len(EXAMPLE_PROMPTS):
        return EXAMPLE_PROMPTS[example_index]
    return ""


# 创建Gradio界面
with gr.Blocks(
    title="AETHER: Create from Thin Air",
    theme=gr.themes.Soft()
) as demo:
    gr.Markdown(
        """
        ## AETHER (Ether / The Fifth Element)
        
        *Peak Performance. Infinite Creativity.*
        
        AETHER is a high-performance image generation engine optimized for Metal (macOS) and CUDA (Linux).
        
        **Features:**
        *   **Flash Attention**: Accelerated inference speed.
        *   **Metal Optimization**: Native support for Apple Silicon.
        *   **8-Step Turbo**: High-quality generation in just 8 steps.
        """
    )
    
    with gr.Row():
        with gr.Column(scale=1):
            # 提示词输入
            prompt_input = gr.Textbox(
                label="提示词",
                placeholder="请在此处输入您的提示信息......",
                lines=4,
                value=""
            )
            
            # 分辨率设置
            resolution_category = gr.Dropdown(
                label="决议类别",
                choices=list(RESOLUTION_PRESETS.keys()),
                value="1024"
            )
            
            resolution = gr.Dropdown(
                label="宽度 x 高度 (比例)",
                choices=list(RESOLUTION_PRESETS["1024"].keys()),
                value="1024x1024 (1:1)"
            )
            
            # 当决议类别改变时更新分辨率选项
            def update_resolution_options(category):
                options = list(RESOLUTION_PRESETS[category].keys())
                return gr.Dropdown(choices=options, value=options[0])
            
            resolution_category.change(
                update_resolution_options,
                inputs=[resolution_category],
                outputs=[resolution]
            )
            
            # 种子设置
            with gr.Row():
                seed_input = gr.Number(
                    label="种子",
                    value=42,
                    precision=0
                )
                random_seed_check = gr.Checkbox(
                    label="随机种子",
                    value=True
                )
            
            # 步骤设置
            steps_slider = gr.Slider(
                label="步骤",
                minimum=1,
                maximum=50,
                value=8,
                step=1
            )
            
            # 时间偏移（对应stable-diffusion.cpp可能需要其他参数）
            time_offset_slider = gr.Slider(
                label="时间偏移",
                minimum=1,
                maximum=10,
                value=3,
                step=1,
                visible=False  # 暂时隐藏，因为sd.cpp可能不支持
            )
            
            # 生成按钮
            generate_btn = gr.Button("产生", variant="primary", scale=1)
            
            # 使用的种子显示
            used_seed = gr.Number(
                label="所用种子",
                value=0,
                interactive=False,
                precision=0
            )
            
            # 示例提示词
            gr.Markdown("### 示例提示")
            gr.Markdown("**三示例**")
            
            example_btns = []
            for i, example in enumerate(EXAMPLE_PROMPTS[:3]):
                btn = gr.Button(
                    f"示例 {i+1}",
                    size="sm",
                    variant="secondary"
                )
                example_btns.append((btn, example))
            
            # 示例按钮点击事件 - 使用闭包避免lambda问题
            def make_example_handler(text):
                def handler():
                    return text
                return handler
            
            for btn, example_text in example_btns:
                btn.click(
                    fn=make_example_handler(example_text),
                    outputs=[prompt_input]
                )
            
            # 显示更多示例
            with gr.Accordion("查看更多示例", open=False):
                for i, example in enumerate(EXAMPLE_PROMPTS[3:], start=4):
                    btn = gr.Button(
                        f"示例 {i}",
                        size="sm",
                        variant="secondary"
                    )
                    btn.click(
                        fn=make_example_handler(example),
                        outputs=[prompt_input]
                    )
        
        with gr.Column(scale=1):
            # 生成的图像显示
            output_image = gr.Image(
                label="生成的图像",
                type="filepath",
                height=600
            )
            
            # 状态信息
            status_text = gr.Textbox(
                label="状态",
                lines=5,
                interactive=False,
                value="准备就绪，请输入提示词并点击生成按钮。"
            )
    
    # 绑定生成事件
    generate_btn.click(
        fn=generate_image,
        inputs=[
            prompt_input,
            resolution_category,
            resolution,
            seed_input,
            random_seed_check,
            steps_slider,
            time_offset_slider
        ],
        outputs=[output_image, status_text, used_seed]
    )
    
    # 检查文件并在启动时显示状态
    missing_files = check_files()
    if missing_files:
        gr.Warning(
            f"警告: 缺少以下文件:\n" + "\n".join(missing_files) + 
            "\n\n请确保所有必需文件已准备好。"
        )


if __name__ == "__main__":
    # 启动界面
    import sys
    
    print("=" * 60)
    print("正在启动 AETHER Web界面...")
    print("=" * 60)
    print("")
    
    # 尝试不同的启动方式
    # 获取端口配置 (Cloud Run会自动设置PORT环境变量)
    server_port = int(os.environ.get("PORT", 7860))
    
    # 尝试不同的启动方式
    try:
        demo.launch(
            server_name="0.0.0.0",  # 必须监听所有接口
            server_port=server_port,
            share=False,
            show_error=True,
            inbrowser=True
        )
    except ValueError as e:
        if "localhost" in str(e) or "shareable link" in str(e):
            print(f"\n注意: {e}")
            print("尝试使用share=True启动...")
            demo.launch(
                server_name="0.0.0.0",
                server_port=server_port,
                share=True,  # 创建公共链接
                show_error=True,
                inbrowser=True
            )
        else:
            raise

