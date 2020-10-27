/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import RxSwift
import RxCocoa

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  @IBOutlet private var tableView: UITableView!
  
  private let disposeBag = DisposeBag()
  private let categories = BehaviorRelay<[EOCategory]>(value: [])
  
  // loading
  private let loading = BehaviorRelay<Bool>(value: true)
  // progress
  private let progressView = DownloadingView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.insertSubview(progressView, at: 0)
    
    categories
      .asObservable()
      .subscribe { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
    }
    .disposed(by: disposeBag)
    
    loading
      .asObservable()
      .subscribe(onNext: { [weak self] (state) in
        DispatchQueue.main.async {
          self?.showActivityIndicator(state)
        }
      })
      .disposed(by: disposeBag)
    
    startDownload()
  }
  
  func startDownload() {
    let eoCategories = EONET.categories
    let downloadedEvents = eoCategories.flatMap { (categories) -> Observable<[EOEvent]> in
      // array of observables
      let observablesArray: [Observable<[EOEvent]>] = categories.map { category -> Observable<[EOEvent]> in
        // return observable array of events for given category
        return EONET.allEvents(forLast: 360, endPoint: category.endpoint)
      }
      // convert to observables sequence
      return Observable.from(observablesArray)
        .merge(maxConcurrent: 2)
        .share(replay: 1)
    }
    
    let updatedCategories = eoCategories.flatMap { categories -> Observable<[EOCategory]> in
      /**
       Scan
       For every element emitted by its source observable, it calls your closure and emits the accumulated value
       */
      return downloadedEvents.scan(categories) { (updated, events) in
        return updated.map { category -> EOCategory in
          let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
          if !eventsForCategory.isEmpty {
            var cat = category
            cat.events = cat.events + eventsForCategory
            return cat
          }
          return category
        }
      }
    }
    
    eoCategories.concat(updatedCategories)
      .bind(to: categories)
      .disposed(by: disposeBag)
    
    downloadedEvents.subscribe(onCompleted: { [weak self] in
      self?.loading.accept(false)
    }).disposed(by: disposeBag)
    
    eoCategories.flatMap { categories in
      return downloadedEvents.scan(0) { (count, events) in
        return count + 1
      }
      .map { Float($0) / Float(categories.count) }
    }
    .observeOn(MainScheduler.instance)
    .bind(to: progressView.progress)
    .disposed(by: disposeBag)
    
    
  }
  
  private func showActivityIndicator(_ show: Bool) {
    switch show {
    case true:
      let activity = UIActivityIndicatorView(style: .gray)
      let barItem = UIBarButtonItem(customView: activity)
      self.navigationItem.rightBarButtonItem = barItem
      activity.startAnimating()
      activity.isHidden = false
    case false:
      if self.navigationItem.rightBarButtonItem != nil {
        self.navigationItem.rightBarButtonItem = nil
      }
    }
  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name) (\(category.events.count))"
    cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)
    guard !category.events.isEmpty else { return }
    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    navigationController!.pushViewController(eventsController, animated:
      true)
  }
  
}

