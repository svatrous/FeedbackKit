//
//  FeedbackViewController.swift
//  FeedbackKit
//
//  Created by Mao Nishi on 8/15/16.
//  Copyright © 2016 Mao Nishi. All rights reserved.
//

import UIKit
import CoreGraphics
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


public struct SendInformation {
    public var selectedTitle: String?
    public var comment: String?
    public var captureImage: UIImage?
    public var reporterName: String?
    public var className: String?
    
    public var feedbackBodyMessage: String {
        get {
            var bodyMessage = ""
            if let selectedTitle = selectedTitle {
                bodyMessage =  "Title: [\(selectedTitle)]\n"
            }
            if let comment = comment {
                bodyMessage = bodyMessage + "Comment: [\(comment)]\n"
            }
            if let reporterName = reporterName {
                bodyMessage = bodyMessage + "Reporter: [\(reporterName)]\n"
            }
            if let className = className {
                bodyMessage = bodyMessage + "ClassName: [\(className)]"
            }
            return bodyMessage
        }
    }
    
    public var captureImageData: Data? {
        get {
            guard let captureImage = captureImage else {
                return nil
            }
            return UIImagePNGRepresentation(captureImage)
        }
    }
}

final public class FeedbackViewController: UIViewController {

    private static var __once: () = {
            let podBundle = Bundle(for: FeedbackViewController.self)
            guard let url = podBundle.url(forResource: "FeedbackKit", withExtension: "bundle") else {
                return
            }
            let bundle = Bundle(url: url)
            //FeedbackUseState.storyboard = UIStoryboard(name: "FeedbackKit", bundle: bundle)
            
        }()

    @IBOutlet weak var screenImageView: UIImageView!
    @IBOutlet weak var picker: UIPickerView!
    @IBOutlet weak var freeCommentTextField: UITextField!
    @IBOutlet weak var reporterField: UITextField!
    
    var reportClassName: String?
    var callerViewController: UIViewController?
    var overlayView: UIView?
    var effectView: UIView?
    var isKeyboardObserving: Bool = false
    var parentView: UIView?
    
    var sendAction: ((_ feedbackViewController: FeedbackViewController, _ sendInformation: SendInformation) -> Void)?
    
    var mailSendCompletion: ((_ feedbackViewController: FeedbackViewController) -> Void)?

    struct FeedbackUseState {
        static var using: Bool = false
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        initialize()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.isKeyboardObserving {
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(FeedbackViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            notificationCenter.addObserver(self, selector: #selector(FeedbackViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            self.isKeyboardObserving = true
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isKeyboardObserving {
            let notificationCenter = NotificationCenter.default
            notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            
            self.isKeyboardObserving = false
        }
    }
    
    fileprivate func initialize() {
        
        if let screenImage = screenshotImage() {
            screenImageView.image = screenImage
        }
        
        if let className = getReportClassName() {
            reportClassName = className
        }
        
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    static func presentFeedbackViewController(_ viewController: UIViewController, action:@escaping ((_ feedbackViewController: FeedbackViewController, _ sendInformation: SendInformation) -> Void)) {
        
        guard FeedbackUseState.using == false else {
            return
        }
        
        guard let feedbackViewController = instantiateInitialViewController() else {
            return
        }
        FeedbackUseState.using = true
        feedbackViewController.sendAction = action
        feedbackViewController.popupViewController(viewController)
    }

    fileprivate static func instantiateInitialViewController() -> FeedbackViewController?  {
        
        struct FeedbackKitStatic {
            static var onceToken: Int = 0
            static var storyboard: UIStoryboard?
        }
        
        // storyboard cache
        _ = FeedbackViewController.__once
        return FeedbackKitStatic.storyboard?.instantiateInitialViewController() as? FeedbackViewController
    }

    fileprivate func screenshotImage() -> UIImage? {
        let screenSize = UIScreen.main.bounds.size
        
        UIGraphicsBeginImageContextWithOptions(screenSize, false, 1.0)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        let application = UIApplication.shared
        application.keyWindow?.layer.render(in: context)
        let screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return screenshotImage
    }
    
    fileprivate func searchReportClass(_ viewController: UIViewController) -> UIViewController? {
        
        let reportViewController: UIViewController = viewController
        
        if let navigationController = viewController as? UINavigationController {
            if let searchResultViewController = navigationController.viewControllers.last {
                return searchReportClass(searchResultViewController)
            }
        } else if let searchResultViewController = reportViewController.presentedViewController {
            return searchReportClass(searchResultViewController)
        }
        return reportViewController
    }
    
    fileprivate func getReportClassName() -> String? {
        guard let reportViewController = UIApplication.shared.keyWindow?.rootViewController,
            let viewController = searchReportClass(reportViewController) else {
            return nil
        }
        return NSStringFromClass(type(of: viewController))
    }
    
    fileprivate func getParentView(_ viewController: UIViewController) -> UIView {
        
        // use cache
        if let parentView = self.parentView {
            return parentView
        }
        
        var sourceController: UIViewController = viewController
        while let parent = sourceController.parent {
            sourceController = parent
        }
        self.parentView = sourceController.view
        return sourceController.view
    }
    
    fileprivate func popupViewController(_ viewController: UIViewController) {
        
        self.callerViewController = viewController
        viewController.addChildViewController(self)
        self.didMove(toParentViewController: viewController)
        
        let parentView = getParentView(viewController)
        let popupView = self.view
        popupView?.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        
        // validate already add view
        guard !parentView.subviews.contains(popupView!) else {
            return
        }
        
        let overlayView = UIView(frame: parentView.bounds)
        self.overlayView = overlayView
        overlayView.backgroundColor = UIColor.clear

        let effectView = EffectView(frame: CGRect(x: 0, y: 0, width: parentView.bounds.size.width + 30, height: parentView.bounds.size.height + 30))
        self.effectView = effectView
        effectView.backgroundColor = UIColor.clear
        effectView.alpha = 0
        overlayView.addSubview(effectView)
        
        // add dismiss button
        let dismissButton = UIButton(type: .custom)
        dismissButton.backgroundColor = UIColor.clear
        dismissButton.frame = overlayView.bounds
        dismissButton.addTarget(self, action: #selector(FeedbackViewController.dismissFeedbackViewController(_:)), for: .touchUpInside)
        
        overlayView.addSubview(dismissButton)
        
        // add popup view
        popupView?.layer.shadowPath = UIBezierPath(rect: (popupView?.bounds)!).cgPath
        popupView?.layer.masksToBounds = false
        popupView?.layer.shadowOffset = CGSize(width: 5, height: 5)
        popupView?.layer.shadowRadius = 5
        popupView?.layer.shadowOpacity = 0.5
        popupView?.layer.shouldRasterize = true
        popupView?.layer.rasterizationScale = UIScreen.main.scale
        overlayView.addSubview(popupView!)
        
        // add overlay view
        parentView.addSubview(overlayView)
        
        presentFeedbackViewController(parentView, popupView: popupView!, overlayView: overlayView, effectView: effectView)
    }
    
    fileprivate func presentFeedbackViewController(_ parentView: UIView, popupView: UIView, overlayView: UIView, effectView: UIView) {
        let startRect = CGRect(x: (parentView.bounds.size.width - popupView.bounds.size.width) / 2,
                                   y: -popupView.bounds.size.height,
                                   width: popupView.bounds.size.width,
                                   height: popupView.bounds.size.height)
        let endRect = CGRect(x: (parentView.bounds.size.width - popupView.bounds.size.width) / 2, y: (parentView.bounds.size.height - popupView.bounds.size.height) / 2, width: popupView.bounds.size.width, height: popupView.bounds.size.height)
        popupView.frame = startRect
        
        UIView.animate(withDuration: 0.35, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            effectView.alpha = 1.0
            popupView.frame = endRect
        }) { (animation:Bool) in
            
        }
    }
    
    @objc
    fileprivate func dismissFeedbackViewController(_ sender: UIButton) {
        dismissFeedbackViewController()
    }
    
    func dismissFeedbackViewController() {
        
        guard let callerViewController = self.callerViewController,
            let overlayView = self.overlayView,
            let effectView = self.effectView else {
                return
        }
        
        let popupView = self.view
        let parentView = getParentView(callerViewController)
        
        let endRect = CGRect(x: (parentView.bounds.size.width - (popupView?.bounds.size.width)!) / 2,
                                 y: -(popupView?.bounds.size.height)!,
                                 width: (popupView?.bounds.size.width)!,
                                 height: (popupView?.bounds.size.height)!)
        
        UIView.animate(withDuration: 0.35,
                                   delay: 0,
                                   options: UIViewAnimationOptions.curveEaseOut,
                                   animations: {
                                    effectView.alpha = 0
                                    popupView?.frame = endRect
        }) { (animation:Bool) in
            overlayView.removeFromSuperview()
            
            FeedbackUseState.using = false
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        freeCommentTextField.endEditing(true)
        reporterField.endEditing(true)
    }
}

extension FeedbackViewController {
    
    @IBAction func tapSendButton(_ sender: AnyObject) {
        
        guard let action = sendAction else {
            return
        }
        
        var sendInformation = SendInformation()
        
        
        if let comment = freeCommentTextField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            sendInformation.comment = comment
        }

        if let reporterName = reporterField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            sendInformation.reporterName = reporterName
        }
        
        let selectedRowIndex = picker.selectedRow(inComponent: 0)
        if let selectedTitle = pickerView(picker, titleForRow: selectedRowIndex, forComponent: 0) {
            sendInformation.selectedTitle = selectedTitle
        }
        
        if let captureImage = screenImageView.image {
            sendInformation.captureImage = captureImage
        }
        
        if let reportClassName = reportClassName {
            sendInformation.className = reportClassName
        }
        
        // execute send action
        action(self, sendInformation)
    }
}

extension FeedbackViewController: UITextFieldDelegate {
    
    func keyboardWillShow(_ notification: Notification) {
        // get keyboard size, keyboard animation duration
        guard let userInfo = notification.userInfo,
            let rect = (userInfo[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue,
            let duration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue,
            let parentView = self.parentView else {
            return
        }
        
        // already moved view
        if self.view.frame.origin.y + (self.view.frame.size.height / 2) < self.parentView?.center.y {
            return
        }
        
        var moveY = -rect.size.height
        
        if self.view.frame.maxY > (parentView.bounds.height - rect.size.height - 50) {
            moveY = (parentView.bounds.height - rect.size.height) - self.view.frame.maxY - 50
        }
        
        // keyboard animation
        UIView.animate(withDuration: duration, animations: {
            let transform = CGAffineTransform(translationX: 0, y: moveY)
            self.view.transform = transform
        }) 
    }
    
    func keyboardWillHide(_ notification: Notification){
        // get keyboard animation duration
        guard let duration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue else {
            return
        }
        
        // keyboard animation
        UIView.animate(withDuration: duration, animations: {
            self.view.transform = CGAffineTransform.identity
        }) 
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension FeedbackViewController: UIPickerViewDelegate {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 6
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // store user default
    }
}

extension FeedbackViewController: UIPickerViewDataSource {
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch (row) {
            case 0:
                return "表示崩れ"
            case 1:
                return "カクカクする"
            case 2:
                return "バグかも"
            case 3:
                return "使いづらい"
            case 4:
                return "見辛い"
            default:
                return "その他"
        }
    }
}

final class EffectView: UIView {
    
    override func draw(_ rect: CGRect) {
        guard let context: CGContext = UIGraphicsGetCurrentContext(),
            let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB() else {
            return
        }
        
        let colors: [CGFloat] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75]
        let locations: [CGFloat] = [0.0, 1.0]
        let locationsCount: size_t = 2
        let gradient = CGGradient(colorSpace: colorSpace, colorComponents: colors, locations: locations, count: locationsCount)
    
        let center: CGPoint = CGPoint(x: bounds.size.width / 2, y: bounds.size.height / 2)
        
        let radius = min(bounds.size.width, bounds.size.height)
        context.drawRadialGradient (gradient!, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: CGGradientDrawingOptions.drawsBeforeStartLocation)
    }
}
