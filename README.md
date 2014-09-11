# README #

FSProgress is a feedback system which includes a queuing system. It handles multiple "services" intelligently. It was originally made to improve the user feedback in Volvo On Call but can be skinned and changed to work in other projects as well.

It uses GCD as a Singelton and can be messaged by sending objects that conform to the **FSData** protocol.


### How do I get set up? ###

Easy. Just import: 
```
#!objective-c
FSProgress.h
```
and add it to your root view controller like so:

```
#!objective-c
[[FSServiceActivityView sharedInstance] setRootViewController:self andFont:[UIFont systemFontOfSize:14]];

```

Original developer is Sebastian Buks <sebastian.buks@mobiento.com>