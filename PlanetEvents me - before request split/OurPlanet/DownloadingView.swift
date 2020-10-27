//
//  DownloadingView.swift
//  OurPlanet
//
//  Created by Danyl Timofeyev on 01.10.2020.
//  Copyright © 2020 Ray Wenderlich. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class DownloadingView: UIStackView {
  
  let progressView = UIProgressView()
  let valueLabel = UILabel()
  
  var progress = BehaviorSubject<Float>(value: 0.0)
  let disposeBag = DisposeBag()

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    translatesAutoresizingMaskIntoConstraints = false
    
    spacing = 0
    distribution = .fillEqually
    axis = .horizontal
    
    if let superview = superview {
      bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
      leftAnchor.constraint(equalTo: superview.leftAnchor).isActive = true
      rightAnchor.constraint(equalTo: superview.rightAnchor).isActive = true
      heightAnchor.constraint(equalToConstant: 38).isActive = true
      backgroundColor = .white

      progressView.translatesAutoresizingMaskIntoConstraints = false
      
      let progressWrap = UIView()
      progressWrap.backgroundColor = .white
      progressWrap.addSubview(progressView)
      
      progressView.heightAnchor.constraint(equalToConstant: 4.0).isActive = true
      progressView.widthAnchor.constraint(equalTo: progressWrap.widthAnchor, multiplier: 1.0).isActive = true
      progressView.centerYAnchor.constraint(equalTo: progressWrap.centerYAnchor, constant: 0.0).isActive = true
      progressView.centerXAnchor.constraint(equalTo: progressWrap.centerXAnchor, constant: 0.0).isActive = true
      
      valueLabel.text = "Downloads"
      valueLabel.textAlignment = .center
      addArrangedSubview(valueLabel)
      addArrangedSubview(progressWrap)
      
      progress
      .asObserver()
        .subscribe(onNext: { [weak self] value in
          DispatchQueue.main.async {
            self?.progressView.progress = value
            print("Progress: \(value)")
            self?.valueLabel.text = "Downloaded: \(Int((value * 100).rounded()))%"
          }
          }, onCompleted: { [weak self] in
            DispatchQueue.main.async {
              self?.valueLabel.text = "Completed"
              self?.progressView.progress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              self?.removeFromSuperview()
            }
        })
        .disposed(by: disposeBag)
    }
  }

}
