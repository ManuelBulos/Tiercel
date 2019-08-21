
# iOS native level background download detailed

- [Ideal and Reality](#idealandReality)
- [Do not forget the heart](#donotforgettheheart)
- [Background download](#backstagedownload)
  - [URLSession](#urlsession)
  - [URLSessionDownloadTask](#urlsessiondownloadtask)
  - [breakpoint resume](#breakpointresume)
  - [ResumeData](#resumedata)
  - [Structure of ResumeData](#resumeDataStructure)
  - [ResumeData's bug](#resumedatabug)
  - [Specific performance](#concreteperformance)
  - [Downloading process](#downloadingprocess)
  - [Download completed](#downloadcompleted)
  - [Download Error](#downloaderror)
  - [redirect](#redirect)
  - [maximum concurrency](#maximumconcurrency)
  - [Front background switching](#frontbackgroundswitching)
  - [Precautions](#notes)
- [last](#final)



## Original intention

A long time ago, I found a problem that I will face:

> How can I download a bunch of files concurrently and perform all other operations after the download is complete?

Of course, this problem is actually very simple, and there are many solutions. But the first thing I thought about was whether there is a task group concept, very authoritative, very popular, stable and reliable, and written in Swift. Is there a lot of download frameworks on Github? If there is such a wheel, I intend to use it as a dedicated download module in the project. Unfortunately, there are a lot of download frameworks, there are many articles and demos in this area, but the famous authority like `AFNetworking`, `SDWebImage`, star is very much, really no one, and some still use `NSURLConnection` to achieve It's even less written in Swift, which gives me the idea of ​​going to implement one myself.

## Ideal and reality

This kind of wheel, if you want to swear by yourself, can't be casual, and the download framework is not authoritative, so at the beginning I plan to do more things at the same time, try to do more things, and fight for the projects I will be responsible for in the future. Can be used. The first thing to satisfy is the background download. It is well known that the iOS app is paused in the background. To implement the background download, you need to use `URLSessionDownloadTask` according to Apple's rules.

There is a lot of related articles and demos on the Internet, and then I started to happily lick the code. The result was found in half, and it was really simple to implement and there was no online article. The test found that open source wheels and demos also have bugs in many places, imperfections, or complete background downloads. Therefore, I could only continue my in-depth research on my own, but at the time there was really no thorough research in this area, and time was not allowed. I had to use a wheel as soon as possible. So in the end I compromised. I used a relatively easy way to deal with it. I changed it to `URLSessionDataTask`. Although it is not a native support background download, I think there are always some evil ways to achieve it. Finally I wrote `Tiercel`. A download framework that compromises reality, but it has met my needs.

## Do not forget the early heart

Because I didn't encounter the hard download requirements in the background, I haven't looked for other ways to implement it, and I think if you want to do it, you must use `URLSessionDownloadTask` to implement the background download at the native level. As time went by, I always felt that it was a great regret to not complete the original idea, so I finally made up my mind to plan to thoroughly research the background download of iOS.

Finally, [Tiercel 2](https://github.com/Danie1s/Tiercel), which perfectly supports native background downloads, was born. Below I will explain in detail the implementation and precautions of the background download, hoping to help those in need.

## Background download

Regarding the background download, in fact, Apple has provided the document---[Downloading Files in the Background](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background), but the problem to be implemented is better than the documentation. Much more.

### URLSession

First, if you need to implement background downloads, you must create `Background Sessions`.

```swift
private lazy var urlSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.Daniels.Tiercel")
    config.isDiscretionary = true
    config.sessionSendsLaunchEvents = true
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
}()
```

 The `URLSession` created in this way is actually `__NSURLBackgroundSession`:

- You must use the `background(withIdentifier:)` method to create `URLSessionConfiguration`, where the `identifier` must be fixed, and to avoid conflicts with other apps, it is recommended that this `identifier` be associated with the App's `Bundle ID'
- When creating `URLSession`, you must pass in `delegate`
- You must create `Background Sessions` when the app starts, ie its life cycle is almost identical to the App. For ease of use, it is best to use the property of `AppDelegate` or a global variable. The reason will be explained later.

### URLSessionDownloadTask

Background download is only supported by `URLSessionDownloadTask`

```swift
let downloadTask = urlSession.downloadTask(with: url)
downloadTask.resume()
```

The downloadTask created by `Background Sessions` is actually `__NSCFBackgroundDownloadTask`

So far, tasks that support background downloads have been created and turned on, but the real problem is only now

### http

Apple's official documentation ---- [Pausing and Resuming Downloads](https://developer.apple.com/documentation/foundation/url_loading_system/pausing_and_resuming_downloads)

The breakpoint of `URLSessionDownloadTask` depends on `resumeData`

```swift
// save resumeData when canceled
downloadTask.cancel { resumeDataOrNil in
    guard let resumeData = resumeDataOrNil else { return }
    self.resumeData = resumeData
}

// or get it in the urlSession(_:task:didCompleteWithError:) method of the session delegate
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error,
    let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        self.resumeData = resumeData
    }
}

// Restore download with resumeData
guard let resumeData = resumeData else {
    // inform the user the download can't be resumed
    return
}
let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
downloadTask.resume()
```

Under normal circumstances, this can already resume the download task, but in fact it is not so smooth, `resumeData` has a variety of problems.

### ResumeData

In iOS, this `resumeData` is simply a strange existence. If you have studied it, you will feel incredible, because this thing has been changing, and often there are bugs, it seems that Apple does not want us to operate on it.

#### ResumeData Structure

Before iOS12, save `resumeData` directly to `resumeData.plist` to the local, you can see the structure inside.

- Key in iOS 8, resumeData:

```swift
// url
NSURLSessionDownloadURL
// The size of the data that has been accepted
NSURLSessionResumeBytesReceived
// currentRequest
NSURLSessionResumeCurrentRequest
// Etag, the unique identifier of the downloaded file
NSURLSessionResumeEntityTag
// The cache file path that has been downloaded
NSURLSessionResumeInfoLocalPath
// resumeData version
NSURLSessionResumeInfoVersion = 1
// originalRequest
NSURLSessionResumeOriginalRequest

NSURLSessionResumeServerDownloadDate
```

- On iOS 9 - iOS 10, the changes are as follows:
  - `NSURLSessionResumeInfoVersion = 2`, `resumeData` version upgrade
  - `NSURLSessionResumeInfoLocalPath` is changed to `NSURLSessionResumeInfoTempFileName`, and the cache file path becomes the cache file name.
- On iOS 11, the changes are as follows:
  - `NSURLSessionResumeInfoVersion = 4`, `resumeData` version is upgraded again, it should be skipped directly 3
  - If the `cancel-restore` operation is performed on the downloadTask multiple times, the generated `resumeData` will have a key-value pair with a key of `NSURLSessionResumeByteRange`
- In iOS 12, the `resumeData` encoding method changes, you need to use `NSKeyedUnarchiver` to decode, the structure has not changed.

Understanding the `resumeData` structure plays a key role in solving the bugs caused by it and realizing offline breakpoints.

#### ResumeData's Bug

`resumeData` not only has the structure changed, but there are always various bugs.

- On iOS 10.0 - iOS 10.1:
  - Bug: Using the system generated `resumeData` can not directly restore the download, because `currentRequest` and `originalRequest` `NSKeyArchived` encoding exception, iOS 10.2 and above will fix this problem.
  - Solution: After getting `resumeData`, you need to fix it, create a downloadTask with the modified `resumeData`, and assign values ​​to the downloadTask's `currentRequest` and `originalRequest`, [Stack Overflow](https://stackoverflow.com/questions/39346231/resume-nsurlsession-on-ios10/39347461#39347461) There are specific instructions above.
- On iOS 11.0 - iOS 11.2:
  - Bug: Due to the 'cancel-restore' operation on the downloadTask multiple times, the generated `resumeData` will have a key-value pair with the key 'NSURLSessionResumeByteRange`, so the direct download will succeed (actually no), the downloaded file The size directly becomes 0, and iOS 11.3 and above will fix this problem.
  - Solution: Delete the key-value pair whose key is `NSURLSessionResumeByteRange`.
- On iOS 10.3 - iOS 12.1:
  - Bug: Starting with iOS 10.3, just do a `cancel-restore` operation on the downloadTask, use the generated `resumeData` to create a downloadTask, its `originalRequest` is nil, and the latest system version (iOS 12.1) is still the same, though It does not affect the download of files, but it will affect the management of download tasks.
  - Workaround: Use `currentRequest` to match the task. This involves a redirection problem, which will be explained in detail later.

The above is the summary of the changes and bugs of the `resumeData` that have been summarized in different system versions. The specific code can be referred to `Tiercel`.

### Specific performance

The downloadTask that supports background download has been created, the problem of `resumeData` has been solved, and it is now possible to open and resume the download happily. The next thing to face is the specific performance of this downloadTask, which is also the most important part of implementing a download framework.

Support the background download `URLSessionDownloadTask`, the real type is `__NSCFBackgroundDownloadTask`, the specific performance is very different from the ordinary, according to the above table and Apple official documents:

- When `Background Sessions` is created, the system will record its `identifier`. As long as the App restarts, it will create the corresponding `Background Sessions`, and its proxy method will continue to be called.
- If the task is managed by `session`, the tmp format cache file in the download will be in the sandbox's caches folder; if it is not managed by `session` and can be restored, the cache file will be moved to the Tmp folder. If it is not managed by `session` and cannot be restored, the cache file will be deleted. which is:
  - downloadTask is running and calling `suspend` method, the cache file will be in the sandbox caches folder
  - Call `cancelByProducingResumeData` method, the cache file will be in the Tmp folder
  - The `cancel` method is called and the cache file will be deleted.
- Manual Kill App will call `cancelByProducingResumeData` or `cancel` method
  - On iOS 8, manual kill will immediately call the `cancelByProducingResumeData` or `cancel` method, then the `urlSession(_:task:didCompleteWithError:)` proxy method will be called.
  - On iOS 9 - iOS 12, manual kill will stop downloading immediately. When the app restarts, the corresponding `Background Sessions` will be created, then the `cancelByProducingResumeData` or `cancel` method will be called, and then `urlSession(_) will be called. :task:didCompleteWithError:)`Proxy method
- Enter the background, crash or be shut down by the system. There will be another process to manage the download task. The tasks that are not enabled will be automatically opened. The already opened will remain in the original state (continue to run or pause). After the app restarts. , create the corresponding `Background Sessions`, you can use the `session.getTasksWithCompletionHandler(_:)` method to get the task, the session proxy method will continue to be called (if needed)
- The most surprising thing is that as long as there is no manual Kill App, even if you restart the phone, the download task that was originally running after the restart is completed will continue to download.

Now that the rules have been summarized, it is simple to handle:

- Create `Background Sessions` when the app starts.
- Use the `cancelByProducingResumeData` method to pause the task and ensure that the task can be resumed.
  - In fact, you can also use the `suspend` method, but if you do not resume the task immediately after suspending in iOS 10.0 - iOS 10.1, you will not be able to restore the task. This is another bug, so it is not recommended.
- Manual Kill App will call `cancelByProducingResumeData` or `cancel`, and finally call `urlSession(_:task:didCompleteWithError:)` proxy method, which can be centrally processed here, manage downloadTask, save `resumeData`
- Enter the background, crash or be shut down by the system, without affecting the status of the original task. After the App restarts, create the corresponding `Background Sessions` and use `session.getTasksWithCompletionHandler(_:)` to get the task.


#### Download completed

Since the background download is supported, the app may be in different state when the download task is completed, so it is necessary to understand the corresponding performance:

- In the foreground: Like the normal downloadTask, call the relevant session proxy method
- In the background: When all the tasks in `Background Sessions` (note that all tasks, not just download tasks) are completed, the `application(_:handleEventsForBackgroundURLSession:completionHandler:)` method of `AppDelegate` is called to activate the App. Then, as in the foreground, call the relevant session proxy method, and finally call the `urlSessionDidFinishEvents(forBackgroundURLSession:) ` method.
- Crash or App is closed by the system: When all the tasks in `Background Sessions` (note that all tasks, not just download tasks) are completed, the app will be launched automatically, calling ʻAppDelegate``application(_:didFinishLaunchingWithOptions: )` method, then call `application(_:handleEventsForBackgroundURLSession:completionHandler:)` method, when the corresponding `Background Sessions` is created, it will be the same as in the foreground, call the relevant session proxy method, and finally call `urlSessionDidFinishEvents (forBackgroundURLSession:) `method
- Crash or App is closed by the system, open the app to keep the foreground, and create the corresponding `Background Sessions` when all the tasks are completed: When no session is created, only `AppDelegate` `application(_:handleEventsForBackgroundURLSession:completionHandler: The ` method, when the corresponding `Background Sessions` is created, will be the same as in the foreground, call the relevant session proxy method, and finally call the `urlSessionDidFinishEvents(forBackgroundURLSession:) ` method
- crash or App is closed by the system, open the app, create the corresponding `Background Sessions` and all tasks are completed: the same as in the foreground

to sum up:

- As long as it is not in the foreground, the `application(_:handleEventsForBackgroundURLSession:completionHandler:)` method of `AppDelegate` will be called when all tasks are completed.
- The corresponding session proxy method will be called only if the corresponding `Background Sessions` is created. If it is not in the foreground, it will also call `urlSessionDidFinishEvents(forBackgroundURLSession:) `

Specific treatment:

The first is the creation time of `Background Sessions`. I said earlier:

> You must create `URLSession` when the app starts, ie its life cycle is almost identical to the App. For ease of use, it is best to use the property of `AppDelegate` or a global variable.

Reason: The download task may be completed when the app is in different states, so you need to ensure that the `Background Sessions` has been created when the app starts, so that its proxy method can be called correctly and the next operation is convenient.

According to the performance of the download task, combined with Apple's official documentation:

```swift
// must implement this method in AppDelegate
//
// - identifier: corresponds to the identifier of the Background Sessions
// - completionHandler: needs to be saved
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    if identifier == urlSession.configuration.identifier ?? "" {
            // This is used as the property of AppDelegate to save the completionHandler
            backgroundCompletionHandler = completionHandler
}
}
```

Then call `completionHandler` in the proxy method of the session. Its function is as follows: [application(_:handleEventsForBackgroundURLSession:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622941-application )

```swift
// must implement this method and call the completionHandler on the main thread
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
        let backgroundCompletionHandler = appDelegate.backgroundCompletionHandler else { return }
        
    DispatchQueue.main.async {
        // The completionHandler saved above
        backgroundCompletionHandler()
    }
}
```

At this point, the download is completed and the processing is completed.

#### Download Error

Support for background download of downloadTask fails, in the `urlSession(_:task:didCompleteWithError:)` method inside `(error as NSError).userInfo` may have a key-value pair with the key 'NSURLErrorBackgroundTaskCancelledReasonKey`, which can Obtain information only if the background download task fails. For details, see: [Background Task Cancellation](https://developer.apple.com/documentation/foundation/urlsession/1508626-background_task_cancellation)

```swift
func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error {
        let backgroundTaskCancelledReason = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int
    }
}
```

### Redirect

Support downloads in the background downloadTask, because the App may be in the background, or crash, or shut down by the system, only when all the tasks of `Background Sessions` are completed, it will be activated or started, so the processing of redirects cannot be handled.

Apple's official documentation states:

> Redirects are always followed. As a result, even if you have implemented [`urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411626-urlsession), it is *not* called.

This means that the redirect is always followed and the `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` method is not called.

In the previous section, the `originalRequest` of the downloadTask may be nil. You can only use the `currentRequest` to match the task for management, but the `currentRequest` may also change due to the redirect, and the redirected proxy method will not be called. So you can only use KVO to observe `currentRequest`, so you can get the latest `currentRequest`.

### Maximum number of concurrent

`URLSessionConfiguration` has a `httpMaximumConnectionsPerHost` attribute, which is used to control the number of simultaneous connections to the same host. Apple's documentation shows that the default is 6 for macOS and 4 for iOS. From a literal point of view, its effect should be: If set to N, then the same host has up to N tasks concurrently downloaded, other tasks are waiting, and different host tasks are not affected by this value. But in fact there are many places to pay attention to.

- No data shows what its maximum value is. After testing, setting it to 1000000 is no problem, but if it is set to Int.Max, it will be a problem. For most URLs, it cannot be downloaded (it should be related to the server of the target url) ); if set to less than 1, it cannot be downloaded for most URLs
- When using `URLSessionConfiguration.default` to create a `URLSession`, either on the real machine or on the emulator
  - `httpMaximumConnectionsPerHost` is set to 10000, no matter whether it is the same host, there can be multiple tasks (more than 180 tested) concurrent download
  - `httpMaximumConnectionsPerHost` is set to 1. For the same host, only one task can be downloaded at the same time. Different hosts can have multiple tasks concurrently downloaded.
- When using `URLSessionConfiguration.background(withIdentifier:)` to create a `URLSession` that supports background downloads
  - on the simulator
    - `httpMaximumConnectionsPerHost` is set to 10000, no matter whether it is the same host, there can be multiple tasks (more than 180 tested) concurrent download
    - `httpMaximumConnectionsPerHost` is set to 1. For the same host, only one task can be downloaded at the same time. Different hosts can have multiple tasks concurrently downloaded.
  - On the real machine
    - `httpMaximumConnectionsPerHost` is set to 10000, regardless of whether it is the same host, the number of concurrent downloads is limited (currently the maximum is 6)
    - `httpMaximumConnectionsPerHost` is set to 1. For the same host, only one task can be downloaded at the same time. The number of concurrent downloads of different hosts is limited (currently the maximum is 6)
    - Even if you use multiple `URLSession` to open the download, the number of tasks that can be downloaded concurrently will not increase.
    - The following are restrictions on the number of concurrent systems
      - iOS 9 on iPhone SE is 3
      - iOS 10.3.3 on iPhone 5 is 3
      - iOS 11.2.5 on iPhone 7Plus is 6
      - iOS 12.1.2 on iPhone 6s is 6
      - iOS 12.2 on iPhone XS Max is 6

From the above points, it can be concluded that the system will limit the number of concurrent tasks due to the support of the background URL's `URLSession` feature, so as to reduce the resource overhead. At the same time, for different hosts, even if `httpMaximumConnectionsPerHost` is set to 1, there will be multiple tasks concurrently downloaded, so you can't use `httpMaximumConnectionsPerHost` to control the number of concurrent download tasks. [Tiercel 2](https://github.com/Danie1s/Tiercel) is a control that performs concurrency by judging the number of tasks being downloaded.

### Front and background switching

In the downloadTask running, the App performs background switching, which will cause the `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` method not to be called.

- On iOS 12 - iOS 12.1, iPhone
  8 In the following real machine, the App enters the background and then returns to the foreground. The agent method of the progress is not called. When entering the background again, there is a short time to call the agent method of the progress.
- In iOS 12.1, iPhone XS simulator, the foreground background switching is performed multiple times, and the agent method that occasionally shows progress is not called, the real machine will not visually
- In iOS 11.2.2, iPhone 6 real machine, the foreground background switch, the agent method that will show progress is not called, there are opportunities to recover after multiple switching

The above is the problem I found after testing some models, not covering all models, more situations can be tested by myself.

Solution: Use the notification listener `UIApplication.didBecomeActiveNotification`, delay the 0.1 second call `suspend` method, then call the `resume` method

### Precautions

- Sandbox path: Run and stop the project with Xcode, you can achieve the effect of App crash, but whether you use real machine or simulator, every time you run Xcode, it will change the sandbox path, which will cause the system to downloadTask related files. The operation failed. In some cases, the system recorded the last project sandbox path, which eventually led to errors such as unable to open the task download, find the folder, and so on. I just encountered this situation at the beginning, I don't know why, so I feel unpredictable and can't solve it. Everyone must pay attention when developing tests.
- Real machine and emulator: Due to the fact that there are too many features and precautions in iOS background downloading, and there are certain differences between different iOS versions, it is a convenient choice to use the simulator for development and testing. However, some features will behave differently on real machines and emulators. For example, the number of concurrent downloads on a simulator is very large, but on a real machine is very small (6 on iOS 12), so be sure to Test or verify on the real machine, the result of the real machine shall prevail.
- Cache file: Earlier said that the recovery download depends on `resumeData`, in fact, you need the corresponding cache file, you can get the file name of the cache file in `resumeData` (the cache file path is obtained in iOS 8), because before It is recommended to use the `cancelByProducingResumeData` method to pause the task, then the cache file will be moved to the Tmp folder of the sandbox. The data of this folder will be automatically cleaned up by the system at some time, so it is best to extra if just in case. Save one.

## At last

If you have the patience to read the previous content carefully, then congratulations, you have already understood all the features and precautions of the iOS background download, and you also understand why there is no open source framework for the full implementation of the background download, because of the bug. And the situation to be dealt with is really too much. This article is just a summary of my personal, there may be no problems or details found, if there are new findings, please leave a message.

At present, [Tiercel 2](https://github.com/Danie1s/Tiercel) has been released, which supports the background download perfectly. It also adds functions such as file verification. You need to know more details. You can refer to the code. Welcome to use. , test, submit bugs and suggestions.
