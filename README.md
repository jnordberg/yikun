
yikun
=====

Command line tool for controlling Xiaomi Yi cameras


Installation
------------

With node.js installed do:

```
npm install -g yikun
```


Usage
-----

```
  Usage: yikun [options] [command]


  Commands:

    capture [options]            trigger camera shutter
    put [options] <camera_path>  upload a file to the camera
    cat [options] <camera_path>  read a file from camera
    rm <camera_path>             remove file from camera
    ls <camera_path>             list directory on camera
    battery                      display battery status
    clock [options] [date]       view or set the camera clock
    cmd <json>                   send json command
    exec <command>               execute command in ambarella shell
    reboot                       reboot the camera

  Options:

    -h, --help                     output usage information
    -V, --version                  output the version number
    -v, --verbose                  enable verbose logging
    -A --camera-address [address]  address to camera, default 192.168.42.1

```


Ambarella Shell
---------------

To see the available commands run `yikun exec help`.

**Be careful playing with these, you can brick your camera!**

```
$ yikun exec help
supported built-in commands:
  addr2func bp    cardmgr   cat
  cd    chmod   config    cp
  cpu   date    deletedir dmesg
  dramcfg   drives    dsputil   echo
  eeprom    eval    false   ffuc
  format    hal   help    history
  hotboot   ioerr   jobs    kill
  ls    md5   mesg    mkboot
  mkdir   morph   mv    flashdb
  nice    poweroff  pref    ps
  pwd   ramdisk   readb   readl
  readw   reboot    reset   resume
  rm    rmdir   savebin   sleep
  suspend   sysmon    t   test
  time    touch   trap    true
  vol   writeb    writel    writew
  yyinfo    usbclass  ver   vin
  sm    corefreq  dramfreq  idspfreq
  dll   cleandir  volcfg    firmfl
  nvd   nftl    bbt   romfs
  lu_example_util lk_example_util wifi    net
  lu_util   lk_util   ipclog    ipctest
  ipcmutex  ipcslock  ipcstat   ipcprog
  ipcirq    boss
```


License
-------

**The MIT License (MIT)**
Copyright (c) 2016 Johan Nordberg

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
