
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
    reboot                       reboot the camera

  Options:

    -h, --help                     output usage information
    -V, --version                  output the version number
    -v, --verbose                  enable verbose logging
    -A --camera-address [address]  address to camera, default localhost

```

License
-------

MIT
