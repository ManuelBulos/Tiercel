//
//  ViewController1.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController1: UIViewController {

    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var validationLabel: UILabel!


//    lazy var URLString = "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Office_2016_16.10.18021001_Installer.pkg"
    lazy var URLString = "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"
    var sessionManager = appDelegate.sessionManager1

    override func viewDidLoad() {
        super.viewDidLoad()

        if let task = sessionManager.tasks.safeObject(at: 0) {
            updateUI(task)
        }
    }

    private func updateUI(_ task: DownloadTask) {
        let per = task.progress.fractionCompleted
        progressLabel.text = "progress： \(String(format: "%.2f", per * 100))%"
        progressView.progress = Float(per)
        speedLabel.text = "speed： \(task.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "remaining time: \(task.timeRemaining.tr.convertTimeToString())"
        startDateLabel.text = "start date： \(task.startDate.tr.convertTimeToDateString())"
        endDateLabel.text = "end date： \(task.endDate.tr.convertTimeToDateString())"
        var validation: String
        switch task.validation {
        case .unkown:
            validationLabel.textColor = UIColor.blue
            validation = "UNKNOWN"
        case .correct:
            validationLabel.textColor = UIColor.green
            validation = "CORRECT"
        case .incorrect:
            validationLabel.textColor = UIColor.red
            validation = "INCORRECT"
        }
        validationLabel.text = "VALIDATION： \(validation)"
    }
    
    @IBAction func start(_ sender: UIButton) {
        sessionManager.download(URLString)?.progress { [weak self] (task) in
            self?.updateUI(task)
        }.success { [weak self] (task) in
            self?.updateUI(task)
            // Download task succeeded

        }.failure { [weak self] (task) in
            self?.updateUI(task)
            
            if task.status == .suspended {
                // The download task has been suspended
            }
            if task.status == .failed {
                // Download task failed
            }
            if task.status == .canceled {
                // Download task canceled
            }
            if task.status == .removed {
                // Download task removed
            }
        }.validateFile(code: "9e2a3650530b563da297c9246acaad5c", type: .md5, { [weak self] (task) in
            self?.updateUI(task)
            if task.validation == .correct {
                TiercelLog("Correct file")
            } else {
                TiercelLog("File error")
            }
        })
    }

    @IBAction func suspend(_ sender: UIButton) {
        sessionManager.suspend(URLString)
    }


    @IBAction func cancel(_ sender: UIButton) {
        sessionManager.cancel(URLString)
    }

    @IBAction func deleteTask(_ sender: UIButton) {
        sessionManager.remove(URLString, completely: false)
    }

    @IBAction func clearDisk(_ sender: Any) {
        sessionManager.cache.clearDiskCache()
    }
}

