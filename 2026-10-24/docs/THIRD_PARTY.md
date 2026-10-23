# Third-party components and distribution notices

Verified on 2026-10-24 against the local Godot 4.7.2 binary, the bundled font license and OTF metadata, and the official upstream sources linked below. The export pipeline now generates accessible license files and verifies the repackaged macOS signature. Final Web/macOS exports passed. The macOS archive was re-extracted and its signature and notice bytes verified; all five Web license files returned HTTP 200 with bytes matching the output files.

| Component | Used for | Source and terms |
| --- | --- | --- |
| Godot Engine 4.7.2 stable, official `ed1daf0bf` | Native/Web game runtime | MIT; full engine notice below. [Official license](https://godotengine.org/license/) and [distribution guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html). |
| Components embedded in Godot | Rendering, text, audio, platform support, and other runtime facilities | Multiple compatible licenses, separate from the engine MIT. Preserve exact-version [COPYRIGHT.txt](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt), including copyright entries and license bodies. |
| Noto Sans CJK JP Medium v2.004 | Japanese UI typeface | Copyright © 2014–2021 Adobe. SIL OFL 1.1; full bundled text below. [Official source family](https://github.com/notofonts/noto-cjk), [official license](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE). |

The models and numerically synthesized sounds are original project assets. Their provenance and generator files are listed in [ASSETS.md](ASSETS.md). They do not add third-party asset notices. No license for the project's original code or assets is newly granted by this document.

## Exact runtime metadata check

`Engine.get_license_text()`, `Engine.get_license_info()`, and `Engine.get_copyright_info()` were queried from the actual Godot 4.7.2 executable. The runtime returned 102 component entries and 19 license texts. The engine MIT text below comes from that executable. These counts are an inventory observation, not a compliance score. Preserve the entire exact-version upstream COPYRIGHT file when packaging, or generate a complete human-readable notice from both runtime component entries and the referenced license bodies; listing only license names or only component names is insufficient.

## Implemented accessible package layout

`scripts/export_licenses.gd` queries the configured Godot binary at export time and writes plain UTF-8 notices. `scripts/godot.mjs` places them at:

```text
TENSAI.app/Contents/Resources/licenses/
  GODOT_LICENSE.txt       complete Engine.get_license_text()
  GODOT_COPYRIGHT.txt     all Engine.get_copyright_info() entries + all get_license_info() bodies
  NOTO_OFL.txt            Adobe copyright above + complete fonts/LICENSE.txt
  NOTICES.txt             component names, versions, and source URLs
```

The pipeline writes `builds/README-LICENSES.txt` beside `TENSAI.zip`, pointing to the extracted bundle's `Contents/Resources/licenses/` directory (Finder: Show Package Contents). The bundle also includes `licenses/index.html`. Notices are added before a fresh ad-hoc signature, verified with `codesign --verify --deep --strict`, then repackaged with `ditto`. The final archive is extracted into a temporary verification directory, its signature is checked again, and packaged notice bytes are compared with their staged copies. The signed `.app` is also retained beside the ZIP. Temporary staging is removed after success or failure. This is local ad-hoc signing, not Developer ID signing or notarization.

For Web exports the same files are generated into `dist/licenses/`. The HTML shell places a visible “Licenses” link in a separate 32px footer outside the canvas while the pointer is unlocked, including loading, title, and pause. The link opens a separate tab. Pointer lock hides the footer during active play, and the loading overlay leaves the footer visible. The canvas has a matching height constraint so the link does not cover gameplay. The HTML link targets the generated human-readable license index; source-only docs and `.pck` contents are not the reading path.

The final build pipeline extracted the repackaged archive into a clean verification directory, validated its signature, and compared the packaged notice bytes. HTTP reads from the output server returned all five license files intact; results are in `verification/license-http.json`. This checks served files and package contents; it is not Developer ID signing or notarization.

`build-info.json` now separates the Git revision from `sourceDirty` (the actual repository status) and points to `source-manifest.json`. The latter lists every regular file under `game/` with a SHA-256 and a canonical manifest hash, excluding `game/.godot/` import caches and `.DS_Store`; `.import` source settings remain included. The artifact SHA-256 continues to identify the resulting PCK or repackaged ZIP. A dirty build is explicitly identified and is not represented as identical to its Git revision.

## Godot Engine MIT notice

```text
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Noto Sans CJK JP Medium notice

Copyright © 2014–2021 Adobe (http://www.adobe.com/).

The following is the complete license bundled with the unmodified font:

```text
This Font Software is licensed under the SIL Open Font License,
Version 1.1.

This license is copied below, and is also available with a FAQ at:
http://scripts.sil.org/OFL

-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font
creation efforts of academic and linguistic communities, and to
provide a free and open framework in which fonts may be shared and
improved in partnership with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply to
any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software
components as distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to,
deleting, or substituting -- in part or in whole -- any of the
components of the Original Version, by changing formats or by porting
the Font Software to a new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed,
modify, redistribute, and sell modified and unmodified copies of the
Font Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components, in
Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the
corresponding Copyright Holder. This restriction only applies to the
primary font name as presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created using
the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.
```
