//
//  FImagePresentationViewer.swift
//  FImagePresentationViewer
//
//  Created by Firas Al Khatib Al Khalidi on 11/10/17.
//  Copyright © 2017 Firas Al Khatib Al Khalidi. All rights reserved.
//

import UIKit
import PBImageView

protocol FImagePresentationViewerDelegate: class {
    func fImagePresentationViewer(didShowPresentationViewer presentationViewer: FImagePresentationViewer)
    func fImagePresentationViewer(didDismissPresentationViewer presentationViewer: FImagePresentationViewer)
}
class FImagePresentationViewer: NSObject {
    static var shared: FImagePresentationViewer = FImagePresentationViewer()
    weak var delegate: FImagePresentationViewerDelegate?
    fileprivate var keyWindow: UIWindow {
        return UIApplication.shared.delegate!.window!!
    }
    var animationDuration: Double = 0.3
    fileprivate var window: UIWindow = {
        let window = UIWindow()
        window.backgroundColor = .clear
        window.windowLevel = UIWindowLevelStatusBar
        return window
    }()
    
    fileprivate(set) var isPresented: Bool = false
    fileprivate var blurView: UIVisualEffectView = UIVisualEffectView()
    fileprivate var imageView: PBImageView = PBImageView(image: nil)
    fileprivate var scrollView: UIScrollView = UIScrollView()
    fileprivate weak var sourceImageView: UIImageView?
    fileprivate var dismissalPanGesture: UIPanGestureRecognizer!
    fileprivate var doubleTapZoomGesture: UITapGestureRecognizer!
    fileprivate var dynamicAnimator: UIDynamicAnimator!
    fileprivate var attachementBehavior: UIAttachmentBehavior!
    override fileprivate init(){
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        scrollView.maximumZoomScale = 3
        scrollView.delegate = self
        dismissalPanGesture = UIPanGestureRecognizer(target: self, action: #selector(scrollViewPanned(gesture:)))
        dismissalPanGesture.maximumNumberOfTouches = 1
        dismissalPanGesture.minimumNumberOfTouches = 1
        doubleTapZoomGesture = UITapGestureRecognizer(target: self, action: #selector(scrollViewDoubleTapped(gesture:)))
        doubleTapZoomGesture.numberOfTouchesRequired = 1
        doubleTapZoomGesture.numberOfTapsRequired = 2
        doubleTapZoomGesture.cancelsTouchesInView = false
        doubleTapZoomGesture.delegate = self
        scrollView.addGestureRecognizer(dismissalPanGesture)
        scrollView.clipsToBounds = false
        scrollView.addGestureRecognizer(doubleTapZoomGesture)
        dynamicAnimator = UIDynamicAnimator(referenceView: window)
        scrollView.pinchGestureRecognizer?.addTarget(self, action: #selector(scrollViewPinched(gesture:)))
    }
    @objc fileprivate func scrollViewPinched(gesture: UIPinchGestureRecognizer){
        if gesture.state == .ended{
            if gesture.velocity < 0 && scrollView.isZoomBouncing && scrollView.zoomScale == 1{
                dismiss()
            }
        }
    }
    @objc fileprivate func scrollViewDoubleTapped(gesture: UITapGestureRecognizer){
        if scrollView.zoomScale > 1{
            scrollView.setZoomScale(1, animated: true)
        }
        else{
            scrollView.zoom(to: CGRect(origin: gesture.location(in: scrollView), size: .zero), animated: true)
        }
    }
    @objc fileprivate func scrollViewPanned(gesture: UIPanGestureRecognizer){
        let locationInView: CGPoint = gesture.location(in: window)
        let locationInScrollView: CGPoint = gesture.location(in: scrollView)
        switch gesture.state {
        case .began:
            dynamicAnimator.removeAllBehaviors()
            let centerOffset: UIOffset = UIOffset(horizontal: locationInScrollView.x - scrollView.bounds.midX,
                                                  vertical: locationInScrollView.y - scrollView.bounds.midY)
            attachementBehavior = UIAttachmentBehavior(item: scrollView, offsetFromCenter: centerOffset, attachedToAnchor: locationInView)
            dynamicAnimator.addBehavior(attachementBehavior)
        case .changed:
            attachementBehavior.anchorPoint = locationInView
            break
        case .ended:
            dynamicAnimator.removeAllBehaviors()
            let velocity = gesture.velocity(in: scrollView)
            if sqrt(pow(velocity.x, 2) + pow(velocity.y, 2)) > 2500 {
               dismiss(withFinalVelocity: velocity)
            }
            else{
                UIView.animate(withDuration: animationDuration, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.7, options: .curveLinear, animations: {
                    self.scrollView.transform = CGAffineTransform.identity
                    self.scrollView.frame.origin = .zero
                    self.scrollView.frame.size = self.window.frame.size
                })
            }
        case .cancelled:
            dynamicAnimator.removeAllBehaviors()
            self.scrollView.contentInset = .zero
            self.scrollView.transform = CGAffineTransform.identity
            self.scrollView.frame.origin = .zero
            self.scrollView.frame.size = self.window.frame.size
        case .failed:
            dynamicAnimator.removeAllBehaviors()
            self.scrollView.contentInset = .zero
            self.scrollView.transform = CGAffineTransform.identity
            self.scrollView.frame.origin = .zero
            self.scrollView.frame.size = self.window.frame.size
        default:
            break
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(fromImageView imageView: UIImageView) {
        imageView.isHidden = true
        sourceImageView = imageView
        self.imageView.image = imageView.image
        self.imageView.isHidden = true
        self.imageView.clipsToBounds = true
        self.imageView.layer.cornerRadius = imageView.layer.cornerRadius
        window.makeKeyAndVisible()
        add(fullScreenSubviewTowindow: blurView)
        add(fullScreenSubviewTowindow: scrollView)
        self.imageView.frame = imageView.superview!.convert(imageView.frame, to: window)
        scrollView.addSubview(self.imageView)
        self.imageView.contentMode = imageView.contentMode
        self.imageView.isHidden = false
        let animation = CABasicAnimation(keyPath:"cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.fromValue = self.imageView.layer.cornerRadius
        animation.toValue = 0
        animation.duration = animationDuration
        animation.isRemovedOnCompletion = false
        self.imageView.layer.add(animation, forKey: "cornerRadius")
        UIView.animateKeyframes(withDuration: animationDuration, delay: 0, options: UIViewKeyframeAnimationOptions.calculationModePaced, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.8, animations: {
                self.blurView.effect = UIBlurEffect(style: UIBlurEffectStyle.dark)
            })
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5, animations: {
                self.imageView.frame = self.scrollView.frame
                self.imageView.contentMode = .scaleAspectFit
            })
        }) { (completed) in
            self.isPresented = true
            self.delegate?.fImagePresentationViewer(didShowPresentationViewer: self)
        }
    }
    
    fileprivate func add(fullScreenSubviewTowindow subview: UIView) {
        window.addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        subview.topAnchor.constraint(equalTo: window.topAnchor).isActive = true
        subview.leftAnchor.constraint(equalTo: window.leftAnchor).isActive = true
        subview.rightAnchor.constraint(equalTo: window.rightAnchor).isActive = true
        subview.bottomAnchor.constraint(equalTo: window.bottomAnchor).isActive = true
        window.layoutIfNeeded()
    }
    @objc fileprivate func orientationChanged(){
        dismissalPanGesture.isEnabled = false
        scrollView.zoomScale = 1
        scrollView.contentInset = .zero
        imageView.frame = scrollView.frame
        scrollView.contentSize = imageView.bounds.size
        dismissalPanGesture.isEnabled = true
    }
    func dismiss(withFinalVelocity velocity: CGPoint? = nil) {
        self.dynamicAnimator.removeAllBehaviors()
        if sourceImageView != nil {
            let animation = CABasicAnimation(keyPath:"cornerRadius")
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            animation.fromValue = 0
            animation.toValue = sourceImageView!.layer.cornerRadius
            animation.duration = animationDuration
            animation.isRemovedOnCompletion = false
            self.imageView.layer.add(animation, forKey: "cornerRadius")
        }
        UIView.animate(withDuration: animationDuration, animations: {
            self.blurView.effect = nil
            if self.sourceImageView == nil {
                self.imageView.alpha = 0
                if velocity == nil {
                    self.scrollView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                }
                else {
                    let push = UIPushBehavior(items: [self.scrollView], mode: .instantaneous)
                    push.magnitude = sqrt(pow(velocity!.x, 2) + pow(velocity!.y, 2))
                    push.pushDirection = CGVector(dx: velocity!.x, dy: velocity!.y)
                    self.dynamicAnimator.addBehavior(push)
                }
            }
            else {
                self.scrollView.transform = CGAffineTransform.identity
                self.scrollView.contentInset = .zero
                self.scrollView.frame.size = self.window.frame.size
                self.scrollView.zoomScale = 1
                
                self.imageView.frame = self.sourceImageView!.superview!.convert(self.sourceImageView!.frame, to: self.scrollView)
                self.imageView.contentMode = self.sourceImageView!.contentMode
            }

        }) { (completed) in
            self.blurView.removeFromSuperview()
            self.imageView.removeFromSuperview()
            self.scrollView.removeFromSuperview()
            self.scrollView.transform = CGAffineTransform.identity
            self.isPresented = false
            self.sourceImageView?.isHidden = false
            self.scrollView.contentInset = .zero
            self.scrollView.zoomScale = 1
            self.window.removeFromSuperview()
            self.window.isHidden = true
            self.keyWindow.makeKeyAndVisible()
            self.delegate?.fImagePresentationViewer(didDismissPresentationViewer: self)
        }

    }
}
extension FImagePresentationViewer: UIGestureRecognizerDelegate {
    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
extension FImagePresentationViewer: UIScrollViewDelegate{
    fileprivate func colorAlpha(perZoom zoom: CGFloat)-> CGFloat {
        return 10*zoom - 10
    }
    internal func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale == 1 {
            dismissalPanGesture.isEnabled = true
        }
        else{
            dismissalPanGesture.isEnabled = false
        }
        if scrollView.zoomScale > 1 || scrollView.zoomScale < 1{
            scrollView.backgroundColor = UIColor.black.withAlphaComponent(colorAlpha(perZoom: scrollView.zoomScale))
            if let image = imageView.image {
                
                let ratioW = imageView.frame.width / image.size.width
                let ratioH = imageView.frame.height / image.size.height
                
                let ratio = ratioW < ratioH ? ratioW:ratioH
                
                let newWidth = image.size.width*ratio
                let newHeight = image.size.height*ratio
                
                let left = 0.5 * (newWidth * scrollView.zoomScale > imageView.frame.width ? (newWidth - imageView.frame.width) : (scrollView.frame.width - scrollView.contentSize.width))
                let top = 0.5 * (newHeight * scrollView.zoomScale > imageView.frame.height ? (newHeight - imageView.frame.height) : (scrollView.frame.height - scrollView.contentSize.height))
                
                scrollView.contentInset = UIEdgeInsetsMake(top, left, top, left)
            }
        }
        else {
            scrollView.backgroundColor = .clear
            scrollView.contentInset = .zero
        }
    }
    internal func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

