//
//  PHPhotoLibrary+Rx.swift
//  Combinestagram
//
//  Created by Danyl Timofeyev on 23.09.2020.
//  Copyright © 2020 Underplot ltd. All rights reserved.
//

import Foundation
import RxSwift
import Photos

extension PHPhotoLibrary {
  
  static var authorized: Observable<Bool> {
    return Observable.create { observer in
      DispatchQueue.main.async {
        if authorizationStatus() == .authorized {
          observer.onNext(true)
          observer.onCompleted()
        } else {
          observer.onNext(false)
          requestAuthorization { (status) in
            observer.onNext(status == .authorized)
            observer.onCompleted()
          }
        }
      }
      return Disposables.create()
    }
  }
  
}
