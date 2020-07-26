# Shell-UI for [Spectrecoin](https://spectreproject.io) daemon

This is a Shell script (in fact a Bash script) which offers a simple
user interface to the Spectrecoin daemon.

Configuration file for Spectrecoin daemon is automatically created during first start.
Please stop daemon if you want to make changes afterwards.

## Licensing

- SPDX-FileCopyrightText: © 2020 Alias Developers
- SPDX-FileCopyrightText: © 2016 SpectreCoin Developers

SPDX-License-Identifier: MIT

## Language settings
For correct display of language specific UTF-8 characters it is very
important to have proper language settings. If you encounter broken characters
on the user interface, you might run the following cmd as root:

```
dpkg-reconfigure locales
```

On the following dialog you need to choose the UTF-8 entry for your language.
For german this will be `de_DE.UTF-8`.

