//
//  DirectoryHelper.swift
//
//
//  Created by Yildirim, Alper on 19.08.2024.
//

import Foundation


struct DirectoryHelper  {

    static func getLogDirectory() -> String {
        do {
            if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                return directory.path
            } else {
                throw NSError(domain: "Logger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents directory not found"])
            }
        } catch {
            Logger.shared.log("Error retrieving documents directory: \(error.localizedDescription)", level: .error)
            return ""
        }
    }
}
