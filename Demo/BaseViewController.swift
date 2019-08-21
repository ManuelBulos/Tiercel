//
//  BaseViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/20.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class BaseViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalTasksLabel: UILabel!
    @IBOutlet weak var totalSpeedLabel: UILabel!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var totalProgressLabel: UILabel!
    
    
    @IBOutlet weak var taskLimitSwitch: UISwitch!
    @IBOutlet weak var cellularAccessSwitch: UISwitch!
    
    /*
     Since the execution of the deleted task,
     the result is asynchronous callback,
     so it is best to use downloadURLStrings as the data source.
     */
    lazy var downloadURLStrings = [String]()

    var sessionManager: SessionManager?

    var URLStrings: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // tableView settings
        automaticallyAdjustsScrollViewInsets = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.register(UINib(nibName: "DownloadTaskCell", bundle: nil), forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 164

        // Check disk space
        let free = UIDevice.current.tr.freeDiskSpaceInBytes / 1024 / 1024
        print("The remaining storage space of the phone is: \(free)MB")

        SessionManager.logLevel = .detailed
        
        updateSwicth()
    }

    func updateUI() {
        guard let downloadManager = sessionManager else { return  }
        totalTasksLabel.text = "Total task：\(downloadManager.completedTasks.count)/\(downloadManager.tasks.count)"
        totalSpeedLabel.text = "Total speed：\(downloadManager.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "remaining time: \(downloadManager.timeRemaining.tr.convertTimeToString())"
        let per = String(format: "%.2f", downloadManager.progress.fractionCompleted)
        totalProgressLabel.text = "total progress: \(per)"

    }
    
    func updateSwicth() {
        guard let downloadManager = sessionManager else { return  }
        taskLimitSwitch.isOn = downloadManager.configuration.maxConcurrentTasksLimit < 3
        cellularAccessSwitch.isOn = downloadManager.configuration.allowsCellularAccess
    }

    func setupManager() {

        // Set the callback of the manager
        sessionManager?.progress { [weak self] (manager) in
                self?.updateUI()

            }.success{ [weak self] (manager) in
                self?.updateUI()
                // Download task succeeded
            }.failure { [weak self] (manager) in
                guard let self = self,
                    let downloadManager = self.sessionManager
                    else { return }
                self.downloadURLStrings = downloadManager.tasks.map({ $0.url.absoluteString })
                self.tableView.reloadData()
                self.updateUI()
                
                if manager.status == .suspended {
                    // manager suspended
                }
                if manager.status == .failed {
                    // manager falied
                }
                if manager.status == .canceled {
                    // manager cancelled
                }
                if manager.status == .removed {
                    // manager removed
                }
        }
    }
}

extension BaseViewController {
    @IBAction func totalStart(_ sender: Any) {
        sessionManager?.totalStart()
        tableView.reloadData()
    }

    @IBAction func totalSuspend(_ sender: Any) {
        sessionManager?.totalSuspend()
    }

    @IBAction func totalCancel(_ sender: Any) {
        sessionManager?.totalCancel()
    }

    @IBAction func totalDelete(_ sender: Any) {
        sessionManager?.totalRemove(completely: false)
    }

    @IBAction func clearDisk(_ sender: Any) {
        guard let downloadManager = sessionManager else { return  }
        downloadManager.cache.clearDiskCache()
        updateUI()
    }
    
    
    @IBAction func taskLimit(_ sender: UISwitch) {
        let isTaskLimit = sender.isOn
        if isTaskLimit {
            sessionManager?.configuration.maxConcurrentTasksLimit = 2
        } else {
            sessionManager?.configuration.maxConcurrentTasksLimit = Int.max
        }
        updateSwicth()
        
    }
    
    @IBAction func cellularAccess(_ sender: UISwitch) {
        sessionManager?.configuration.allowsCellularAccess = sender.isOn
        updateSwicth()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension BaseViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadURLStrings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! DownloadTaskCell

        // The closure of the task references the cell, so the task here uses weak
        cell.tapClosure = { [weak self] cell in
            guard let indexPath = self?.tableView.indexPath(for: cell),
                let URLString = self?.downloadURLStrings.safeObject(at: indexPath.row),
                let task = self?.sessionManager?.fetchTask(URLString)
                else { return }
            
            switch task.status {
            case .running:
                self?.sessionManager?.suspend(URLString)
            case .waiting, .suspended, .failed:
                self?.sessionManager?.start(URLString)
            default: break
            }
        }

        return cell
    }

    // Status updates in each cell should be performed in willDisplay
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObject(at: indexPath.row),
            let task = sessionManager?.fetchTask(URLString)
            else { return }
        
        var image: UIImage = #imageLiteral(resourceName: "suspend")
        switch task.status {
        case .running:
            image = #imageLiteral(resourceName: "resume")
        default:
            image = #imageLiteral(resourceName: "suspend")
        }
        
        let cell = cell as! DownloadTaskCell

        cell.controlButton.setImage(image, for: .normal)
        
        cell.titleLabel.text = task.fileName
        
        cell.updateProgress(task)

        task.progress { [weak cell] (task) in
                cell?.controlButton.setImage(#imageLiteral(resourceName: "resume"), for: .normal)
                cell?.updateProgress(task)
            }
            .success { [weak cell] (task) in
                cell?.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
                cell?.updateProgress(task)
                // Download task succeeded

            }
            .failure { [weak cell] (task) in
                cell?.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
                cell?.updateProgress(task)
                if task.status == .suspended {
                    // The download task has been suspended
                }

                if task.status == .failed {
                    // Download task failed
                }
                if task.status == .canceled {
                    // Download task cancelled
                }
                if task.status == .removed {
                    // Download task removed
                }
            }
    }

    // Since the cell is recycled, the cell that is not in the visible range should not update the state of the cell.
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObject(at: indexPath.row),
            let task = sessionManager?.fetchTask(URLString)
            else { return }

        task.progress { _ in }.success({ _ in }).failure({ _ in})
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

}
