# V07 Material Maps

Downloaded on 2026-09-28 from Poly Haven's official 1K JPEG files. The files are unchanged source bytes; filenames were normalized to `diffuse.jpg`, `normal.jpg`, and `roughness.jpg`. Both textures are 1024 × 1024. Normal maps are OpenGL (`nor_gl`).

Poly Haven states that its assets are CC0 and may be used and redistributed for any purpose, including commercial work; attribution is not required. Authors are recorded here as provenance. No image processing was applied.

- License: [Poly Haven license](https://polyhaven.com/license)
- File API: `https://api.polyhaven.com/files/{asset_id}`
- Asset pages: [Worn Shutter](https://polyhaven.com/a/worn_shutter), [Worn Asphalt](https://polyhaven.com/a/worn_asphalt)
- Retrieved files: 6 JPEGs, 4,400,460 bytes total (about 4.20 MiB). The 1K originals exceed the approximate 2 MB budget; the requested maps are preserved at their source quality.

## Worn Shutter

- Author: Dimitrios Savva
- Source asset: [polyhaven.com/a/worn_shutter](https://polyhaven.com/a/worn_shutter)
- License: CC0, as stated on the asset page and [license page](https://polyhaven.com/license)

| Local file | Source map | Original URL | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `public/assets/materials/worn_shutter/diffuse.jpg` | Diffuse, 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_shutter/worn_shutter_diff_1k.jpg | 560,285 | `1e1a84c4f2ce5d005c9c3e8860d23370e2ad6dcc4040cd972803ad700e516a08` |
| `public/assets/materials/worn_shutter/normal.jpg` | Normal (GL), 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_shutter/worn_shutter_nor_gl_1k.jpg | 717,669 | `924e3948a4f654322ddb595b9abca4b0b491d70fd69453f479c108d5ac815c93` |
| `public/assets/materials/worn_shutter/roughness.jpg` | Rough, 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_shutter/worn_shutter_rough_1k.jpg | 223,894 | `8ac4d81745ed173e1cb34da52b6cd429a476245df7cef6285416f4ba7c137dd6` |

## Worn Asphalt

- Author: Amal Kumar
- Source asset: [polyhaven.com/a/worn_asphalt](https://polyhaven.com/a/worn_asphalt)
- License: CC0, as stated on the asset page and [license page](https://polyhaven.com/license)

| Local file | Source map | Original URL | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| `public/assets/materials/worn_asphalt/diffuse.jpg` | Diffuse, 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_asphalt/worn_asphalt_diff_1k.jpg | 914,719 | `3bf71ad290730092ad2aee85e246b2e43318bc1f32261826ba91250e815b5f72` |
| `public/assets/materials/worn_asphalt/normal.jpg` | Normal (GL), 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_asphalt/worn_asphalt_nor_gl_1k.jpg | 1,503,498 | `5f835d192dac296674229a763553f356f5e206bb7f6d812bca5b0f38fc5302a4` |
| `public/assets/materials/worn_asphalt/roughness.jpg` | Rough, 1K JPG | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/worn_asphalt/worn_asphalt_rough_1k.jpg | 480,395 | `ad63ece01a94cb43f57a9d628fa9d28a560bffc8878749998ad3601831ab843f` |

## Validation

- Each downloaded response matched the Poly Haven files API's reported byte count and MD5.
- Local `file` and `sips` inspection identified all six as JPEG images at 1024 × 1024; no conversion or re-encoding was performed.
