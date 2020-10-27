//
//  UIViewController+Rx.swift
//  Combinestagram
//
//  Created by Danyl Timofeyev on 20.09.2020.
//  Copyright © 2020 Underplot ltd. All rights reserved.
//

import RxSwift

extension UIViewController {
  func presentAlert(title: String, message: String) -> Completable {
    Completable.create { (completable) -> Disposable in
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { _ in
        completable(.completed)
      }))
      self.present(alert, animated: true, completion: nil)
      return Disposables.create {
        self.dismiss(animated: true, completion: nil)
      }
    }
  }
}
