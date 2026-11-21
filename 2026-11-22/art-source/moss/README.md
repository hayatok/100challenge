# 金星 cabaret poster — actual local MOSS-Image output

Generated 2026-11-22 (Asia/Tokyo) with the existing local ComfyUI installation, using the local API at `127.0.0.1:8188`. No substitute model or image-generation service was used. The final PNG is the unmodified ComfyUI output, copied to `Game/Assets/Resources/Art/kinsei-poster.png`.

## Reproduction

- ComfyUI source: `C:/comfy/ComfyUI/ComfyUI`, commit `2c75dc1b379a59e0880619d029607af5169a62ef`.
- Python runtime: `C:/comfy/ComfyUI/ComfyUI/.venv/Scripts/python.exe`, PyTorch `2.10.0+cu130`.
- GPU: NVIDIA GeForce RTX 4070 Ti, 12 GB VRAM.
- Diffusion model: `moss_image_sft_int8_convrot.safetensors` (5,413,698,958 bytes).
- Text encoder: `qwen3.5_9b_w4a8_gptq.safetensors`, CLIPLoader type `moss_image`.
- VAE: `flux2-vae_small.safetensors`.
- Seed: `19731122`; 1024 × 1024; 30 steps; CFG 2.5; `er_sde` sampler, `simple` scheduler; denoise 1.
- No LoRA, reference image, prompt upsampler, or postprocessing.
- Exact positive/negative prompts and full node connections: `poster-api.json`; submitter: `generate.py`.
- Prompt ID: `9ad83e1e-8622-47eb-9e57-26569ea6dc05`; server's execution record: `history.json`; execution time 27.42 seconds.
- Original server output: `C:/comfy/ComfyUI/ComfyUI/output/kinsei/kinsei-poster_00001_.png`.
- Final PNG SHA-256: `A54F6E6423FB5AF8FE5628491F38CC680CC9A3E659C097ECBA5D095BD7672ECC`.

To reproduce while the local ComfyUI backend is ready, run `generate.py` using that Python runtime. This saves the graph and submits a new local job. The seed and parameters remain fixed.

## Inspection and integration

Opened and visually inspected the actual PNG at full image size. The generated print has the requested vermilion, aged ivory and ink-black palette; Japanese 金星 headline and Latin CABARET KINSEI are correct and readable. The trumpeter silhouette, starburst, old-paper wear and border form a strong diegetic Showa-period cabaret poster. Minor generated instrument/hand stylization is appropriate at wall-prop scale. This is an environment texture, not UI text or a reference mockup.

Unity resource key: `Art/kinsei-poster`. It should appear as a square poster inside the cabaret environment. Unity scene placement and in-game visibility are verified by the main integration task.

The dedicated hidden backend was started only for this task. After output, models were unloaded and GPU memory released through ComfyUI's `/free` endpoint. No shared settings, packages, model files or unrelated jobs were changed.

## Companion oxblood upholstery

The second requested production asset is `Game/Assets/Resources/Art/kinsei-oxblood-vinyl.png` (Unity key `Art/kinsei-oxblood-vinyl`). It is a 1024-square MOSS scan-style image of dark burgundy diamond/button tufted vintage vinyl. The same model, encoder, VAE and sampling parameters were used, with seed `19731123`. The exact graph is `vinyl-api.json`, submitter `generate-vinyl.py`, and actual local execution evidence is `vinyl-history.json` and `vinyl-submission.json`.

- Prompt ID: `8eefd78c-e273-4cc2-9b36-b3ee0bcb62ee`.
- Execution: 22.97 seconds on the same RTX 4070 Ti.
- Original: `C:/comfy/ComfyUI/ComfyUI/output/kinsei/kinsei-oxblood-vinyl_00001_.png`.
- SHA-256: `2891B9759C8269A642C5A4E8532BDA39B9D1AA30A34B9454A2C15A6BB1F88637`.

The actual output was opened and visually inspected. It has fine vinyl grain, aged oxblood tones and readable tufts without extraneous objects or text. The prompt requested seamless output, but the image was not mathematically seam-corrected; use one tile per banquette back panel or a low repeat count. The integration worker was told this limitation. It is the original unmodified MOSS PNG. Both jobs finished successfully and the dedicated backend was shut down after releasing its model memory.
