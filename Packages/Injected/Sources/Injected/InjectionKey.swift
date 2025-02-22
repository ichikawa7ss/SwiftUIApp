//
//  InjectionKey.swift
//  Injected
//
//  Created by okudera on 2022/02/24.
//  Copyright © 2022 yuoku. All rights reserved.
//

import Foundation

public protocol InjectionKey {

    /// The associated type representing the type of the dependency injection key's value.
    associatedtype Value

    /// The default value for the dependency injection key.
    static var currentValue: Value { get set }
}
