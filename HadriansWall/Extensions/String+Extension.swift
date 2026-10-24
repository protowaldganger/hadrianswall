//
//  String+Extension.swift
//  Hadrian's Wall
//

import Foundation

extension String {
    var localized: String { NSLocalizedString(self, comment: self) }
}
