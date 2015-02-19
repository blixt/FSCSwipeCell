# FSCSwipeCell

[![CI Status](http://img.shields.io/travis/47center/FSCSwipeCell.svg?style=flat)](https://travis-ci.org/47center/FSCSwipeCell)
[![Version](https://img.shields.io/cocoapods/v/FSCSwipeCell.svg?style=flat)](http://cocoadocs.org/docsets/FSCSwipeCell)
[![License](https://img.shields.io/cocoapods/l/FSCSwipeCell.svg?style=flat)](http://cocoadocs.org/docsets/FSCSwipeCell)
[![Platform](https://img.shields.io/cocoapods/p/FSCSwipeCell.svg?style=flat)](http://cocoadocs.org/docsets/FSCSwipeCell)

## Installation

FSCSwipeCell is available through [CocoaPods](http://cocoapods.org). To install it, simply
add the following line to your Podfile:

    pod "FSCSwipeCell"

## What is it?

<img src="http://fat.gfycat.com/CarefreeCreativeAdder.gif" height="268">

This component was built to make swipeable cells behave as one would expect, without taking control of what appears
when you swipe left or right.

### What it does

* Displays additional views (that you provide) under the table view cell when the user swipes it left or right
* Handles the physics of swiping a cell open/closed with distance and velocity thresholds
* Notifies the (optional) delegate of all updates to the state of the cell, such as:
    * The left/right view is about to show (with the option of canceling it and keeping it "closed")
    * The cell has been swiped any distance
    * The cell is done closing (either because the user swiped it shut, or didn't swipe beyond the threshold)
* Repurposes the standard `UITableViewCell`'s `contentView`, so all table view styles are supported
* Lets you assign `leftView` or `rightView` immediately before showing them, so you can reuse one view for all cells

### What it doesn't do

* It doesn't create or handle any content in the left/right views
* It (currently) doesn't allow the cell to stay half-open (e.g., like the Mail app's more/delete buttons)

### Why not one of the other swipeable cell libraries out there?

It really depends on what you're after. This library gives you some more control of how the cell renders when swiped,
but if you just want to show a few buttons when the user swipes left, use [UITableViewRowAction][], or if you want
some more functionality on the buttons, check out [SWTableViewCell][] or [MGSwipeTableCell][]. There are some things
I needed for my app which are out of the scope of those libraries, which is why I made this library. Hopefully all
these libraries together will help cover everyone's needs.

## A note on stability

This is in a very early stage right now and may have bugs lurking in the water. For example, I have not tested it
with iOS 7 so that might not work too well (yet). All pull requests are welcome!

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Author

Blixt, blixt@47center.com

## License

FSCSwipeCell is available under the MIT license. See the LICENSE file for more info.


[UITableViewRowAction]: https://developer.apple.com/library/ios/documentation/UIKit/Reference/UITableViewRowAction_class/index.html
[SWTableViewCell]: https://github.com/CEWendel/SWTableViewCell
[MGSwipeTableCell]: https://github.com/MortimerGoro/MGSwipeTableCell
