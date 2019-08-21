//
//  DownloadTaskCell.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class DownloadTaskCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var bytesLabel: UILabel!
    @IBOutlet weak var controlButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!

    var tapClosure: ((DownloadTaskCell) -> Void)?


    @IBAction func didTapButton(_ sender: Any) {
        tapClosure?(self)
    }

    func updateProgress(_ task: DownloadTask) {
        progressView.progress = Float(task.progress.fractionCompleted)
        bytesLabel.text = "\(task.progress.completedUnitCount.tr.convertBytesToString())/\(task.progress.totalUnitCount.tr.convertBytesToString())"
        speedLabel.text = task.speed.tr.convertSpeedToString()
        timeRemainingLabel.text = "remaining time：\(task.timeRemaining.tr.convertTimeToString())"
        startDateLabel.text = "Starting time：\(task.startDate.tr.convertTimeToDateString())"
        endDateLabel.text = "End time：\(task.endDate.tr.convertTimeToDateString())"
    }

}
