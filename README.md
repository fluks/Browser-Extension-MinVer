# Browser-Extension-MinVer 

## Description

Browser-Extension-MinVer provides a Perl script to find minimum browser
version which supports a certain browser extension. It does this by searching
browser extension strings from the extension's JavaScript files.

## Requirements

    perl >= 5.22
    Module::Build
    Readonly
    File::ShareDir

You need browser compatibility data from
[browser-compat-data](https://github.com/mdn/browser-compat-data/) repository.

## Install

    perl Build.PL
    ./Build
    sudo ./Build install

## Usage

    # Find version from all .js prefixed files from the directory.
    min_ext_ver.pl extension_src_dir

    # Print also the used APIs.
    min_ext_ver.pl -v extension_src_dir

    # Print also files and lines where the API is used.
    min_ext_ver.pl -vv extension_src_dir

    # Find version from the file for only Firefox and Chrome.
    min_ext_ver.pl -b firefox,chr content_script.js

    # For updating the browser compatibility data.
    # First clone https://github.com/mdn/browser-compat-data/
    parse_compatibility_table.pl PATH_TO_CLONED_REPO/webextensions/api/ > extension_compatibility_table.txt
    # Copy it to where the previous version was installed.
    sudo cp extension_compatibility_table.txt /usr/local/share/.../

## Limitations

* Only browser extension API is checked, not the rest of the JavaScript used
in the extension.

* If something from the Extension API is used conditionally, it can't be
detected.

* If there's whitespace between namespace and a method, i.e.
`chrome.storage.    local.    set(...)`, think newlines.

* If part of an API is stored in a variable and it's called using that variable.

* Parameters to functions aren't checked whether they are supported.
