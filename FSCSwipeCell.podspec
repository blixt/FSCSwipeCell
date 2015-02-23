Pod::Spec.new do |s|
  s.name             = 'FSCSwipeCell'
  s.version          = '0.1.4'
  s.summary          = 'A table view cell that can be swiped left and/or right to perform an action.'
  s.description      = <<-DESC
                       Table view cells of this class will reveal a colored area that represents an action when
                       the user swipes left or right on the cell. If the user passes over a certain threshold,
                       the action will be triggered; otherwise, the cell will just bounce back to its default
                       state.
                       DESC
  s.homepage         = 'https://github.com/47center/FSCSwipeCell'
  s.screenshots      = 'http://fat.gfycat.com/CarefreeCreativeAdder.gif'
  s.license          = 'MIT'
  s.author           = { 'Blixt' => 'blixt@47center.com' }
  s.source           = { :git => 'https://github.com/47center/FSCSwipeCell.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/blixt'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'FSCSwipeCell' => ['Pod/Assets/*.png']
  }

  s.frameworks = 'QuartzCore', 'UIKit'
end
