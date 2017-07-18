# README #

FSProgress is a feedback system which includes a queuing system. It handles multiple "services" intelligently. It was originally made to improve the user feedback in a *unnamed world brand car manufacturer app* but can be skinned and changed to work in other projects as well.

It uses GCD as a Singelton and can be messaged by sending objects that conform to the **FSData** protocol.

This is setup as an iOS Framework. Import it as a submodule or build it separately and add it to your project.


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

When adding the framework to your project, make sure to also copy the Media.xcassets folder to your project as the built framework does not include the graphics itself.
