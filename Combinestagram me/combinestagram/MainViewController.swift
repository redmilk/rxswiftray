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

class MainViewController: UIViewController {
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  private var imageCache = [Int]()
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  
  override func viewDidLoad() {
    super.viewDidLoad()

    let imagesShared = images.share()
    imagesShared.subscribe(onNext: { [weak imagePreview] photos in
      guard let preview = imagePreview else { return }
      preview.image = photos.collage(size: preview.frame.size)
    }).disposed(by: bag)
    
    imagesShared
      .throttle(0.5, scheduler: MainScheduler.instance)
      .subscribe(onNext: { [weak self] photos in
        guard let self = self else { return }
        DispatchQueue.main.async {
          self.updateUI(photos: photos)
        }
      }).disposed(by: bag)
    
    imagesShared
      .debug("*", trimOutput: false)
      .filter { $0.isEmpty }
      .subscribe(onNext: { [weak self] _ in
        guard let self = self else { return }
        DispatchQueue.main.async {
          self.updateNavigationIcon()
        }
      }).disposed(by: bag)
  }
  
  @IBAction func actionClear() {
    images.accept([])
    imageCache = []
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    PhotoWriter.save(image)
      .asSingle()
      .subscribe(onSuccess: { [weak self] id in
        guard let self = self else { return }
        self.presentAlert(title: "RxAlert", message: "Saved with id: \(id)")
          .subscribe()
          .disposed(by: self.bag)
        self.actionClear()
        }, onError: { [weak self] error in
          self?.showMessage("Error", description: error.localizedDescription)
      }).disposed(by: bag)
  }
  
  @IBAction func actionAdd() {
    let photosViewController = storyboard!.instantiateViewController( withIdentifier: "PhotosViewController") as! PhotosViewController
    
    let newPhoto = photosViewController.selectedPhoto.share()
    newPhoto
      .takeWhile({ [weak self] (image) -> Bool in
        let count = self?.images.value.count ?? 0
        return count < 6
    })
      .filter { newImage in
        return newImage.size.width > newImage.size.height
    }
    .subscribe(onNext: { [weak self] photo in
      guard let self = self else { return }
      self.images.accept(self.images.value + [photo])
      }, onDisposed: {
        print("completed photo selection")
    }).disposed(by: bag)
    
    newPhoto
      .ignoreElements()
      .subscribe(onCompleted: { [weak self] in
        self?.updateNavigationIcon()
      })
      .disposed(by: bag)
    
    navigationController!.pushViewController(photosViewController, animated: true)
  }
  
  private func updateNavigationIcon() {
    let icon = imagePreview.image?.scaled(CGSize(width: 22, height: 22)) .withRenderingMode(.alwaysOriginal)
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon, style: .done, target: nil, action: nil)
  }
  
  func showMessage(_ title: String, description: String? = nil) {
    let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { [weak self] _ in self?.dismiss(animated: true, completion: nil)}))
    present(alert, animated: true, completion: nil)
  }
  
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 10
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
}
