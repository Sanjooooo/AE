FAE-AE MATLAB framework (MATLAB R2022b)
======================================

How to run:
1) Put all .m files in the same folder.
2) Open MATLAB and set the current folder to this directory.
3) Run: main

Important note:
- This is a runnable FRAMEWORK implementation for your paper prototype.
- The environment, wind field, and coarse reference path are all lightweight and self-contained.
- The file applyOperator_FAEAE.m currently uses a framework-style operator pool compatible with your FAE-AE story.
- If you later want to strictly follow the exact original AE update equations from the source paper, replace only applyOperator_FAEAE.m.

Recommended next steps:
1) Replace generateReferencePath.m with A*/Theta* corridor generation.
2) Add benchmark scenes and multiple runs.
3) Save results for convergence curves, boxplots, and statistical tests.
4) Add ablation switches for Init / AOS / Repair / Regeneration.