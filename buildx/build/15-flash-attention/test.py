# COMMIT-TRACKING: UUID-20240730-170000-DYN1
# Description: Added COMMIT-TRACKING header to test script
# Author: Mr K / GitHub Copilot
#
# File location diagram:
# jetc/                          <- Main project folder
# ├── README.md                  <- Project documentation
# ├── buildx/                    <- Buildx directory
# │   ├── build/                   <- Build stages directory
# │   │   └── 15-flash-attention/  <- Current directory
# │   │       └── test.py          <- THIS FILE
# └── ...                        <- Other project files
#!/usr/bin/env python3
import flash_attn

print('FlashAttention version', flash_attn.__version__)
