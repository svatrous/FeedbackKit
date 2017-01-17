//
//  FeedbackMail.swift
//  FeedbackKit
//
//  Created by Mao Nishi on 8/18/16.
//  Copyright © 2016 Mao Nishi. All rights reserved.
//

import Foundation
import MessageUI

class FeedbackMail: NSObject, MFMailComposeViewControllerDelegate {
    
    var mailSendCompletion: (() -> Void)?

    internal func send(_ emailConfig: Feedback.EmailConfig, sendInformation: SendInformation, callerViewController: UIViewController, mailSendCompletion: @escaping (() -> Void)) {
        
        guard MFMailComposeViewController.canSendMail() else {
            let alertController = UIAlertController(title: "error", message: "mail can not use", preferredStyle: UIAlertControllerStyle.alert)
            callerViewController.present(alertController, animated: true, completion: nil)
            return
        }
        
        self.mailSendCompletion = mailSendCompletion
        
        let mailViewController = MFMailComposeViewController()
        mailViewController.mailComposeDelegate = self
        mailViewController.setToRecipients(emailConfig.toList)
        if let ccList = emailConfig.ccList {
            mailViewController.setCcRecipients(ccList)
        }
        if let bccList = emailConfig.bccList {
            mailViewController.setBccRecipients(bccList)
        }
        if let subject = emailConfig.mailSubject {
            mailViewController.setSubject(subject)
        } else {
            mailViewController.setSubject("Feedbackmail")
        }
        mailViewController.setMessageBody(sendInformation.feedbackBodyMessage, isHTML: false)
        
        if let captureImageData = sendInformation.captureImageData {
            mailViewController.addAttachmentData(captureImageData as Data, mimeType: "image/png", fileName: "feedback.png")
        }
        
        callerViewController.present(mailViewController, animated: true, completion: nil)
        
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        switch result {
        case MFMailComposeResult.sent:
            controller.dismiss(animated: true, completion: {
                if let mailSendCompletion = self.mailSendCompletion {
                    mailSendCompletion()
                }
            })
        case MFMailComposeResult.saved:
            fallthrough
        case MFMailComposeResult.cancelled:
            controller.dismiss(animated: true, completion: nil)
        case MFMailComposeResult.failed:
            let alertController = UIAlertController(title: "mail send error", message: "error:\(error)", preferredStyle: UIAlertControllerStyle.alert)
            controller.present(alertController, animated: true, completion: nil)
        default:
            break
        }
    }

}
