![ctuhl](https://github.com/pellepelster/ctuhl/workflows/ctuhl/badge.svg)

# Commons Tools Utilities Helper and Libraries (cthuhl)

Repository aggregating all the stuff that accumulates over time and may be helpful to others but is not worth an own repository.

## Shell

### Usage

The shell utilities are designed to be used by sourcing the appropiate files, for example

```
#!/usr/bin/env bash

source "${PATH_TO_CTUHL}/download.sh"

ctuhl_ensure_terraform "~/bin"
```

### Available Functions

#### `ctuhl_download_and_verify_checksum ${url} ${target_file} ${checksum}`

Downloads the file given by `${url}` to `${target_file}` and verfies if the downloaded file has the checksum `${checksum}`. If a file is already present at `${target}` download is skipped.

#### `ctuhl_extract_file_to_directory ${compressed_file} ${target_dir}`

Extracts the file given by `${compressed_file}` to the directory `${target_dir}`. Appropiate decompressor is chosen depending on file extension, currently `unzip` for `*.zip` and `tar` for everything else. After uncompress a marker file is written, indicating successful decompression. If this file is present when called decompression is skipped.
