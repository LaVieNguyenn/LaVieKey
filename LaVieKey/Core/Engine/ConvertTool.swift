//
//  ConvertTool.swift
//  LaVieKey
//
//  Text conversion utilities - Ported from OpenKey ConvertTool.cpp
//

import Foundation

/// Utilities for converting Vietnamese text
class ConvertTool {
    
    // MARK: - Settings
    
    var dontAlertWhenCompleted = false
    var toAllCaps = false
    var toAllNonCaps = false
    var toCapsFirstLetter = false
    var toCapsEachWord = false
    var removeMark = false
    var fromCode: UInt8 = 0  // 0: Unicode, 1: TCVN3, 2: VNI
    var toCode: UInt8 = 0
    
    // MARK: - Conversion
    
    /// Convert text based on settings
    func convert(_ sourceString: String) -> String {
        var result = sourceString
        
        // Step 1: Convert code table if needed
        if fromCode != toCode {
            result = convertCodeTable(result, from: fromCode, to: toCode)
        }
        
        // Step 2: Remove marks if needed
        if removeMark {
            result = removeMarks(result)
        }
        
        // Step 3: Convert case
        if toAllCaps {
            result = result.uppercased()
        } else if toAllNonCaps {
            result = result.lowercased()
        } else if toCapsFirstLetter {
            result = capitalizeFirstLetter(result)
        } else if toCapsEachWord {
            result = capitalizeEachWord(result)
        }
        
        return result
    }
    
    // MARK: - Code Table Conversion
    
    private func convertCodeTable(_ text: String, from: UInt8, to: UInt8) -> String {
        // Simple implementation - can be enhanced with full code table lookup
        if from == 0 && to == 0 {
            return text  // Unicode to Unicode - no change
        }
        
        // For now, just return original
        // Full implementation would use code tables from VietnameseData
        return text
    }
    
    // MARK: - Mark Removal
    
    private func removeMarks(_ text: String) -> String {
        let markMap: [Character: Character] = [
            // Lowercase
            "á": "a", "à": "a", "ả": "a", "ã": "a", "ạ": "a",
            "ắ": "a", "ằ": "a", "ẳ": "a", "ẵ": "a", "ặ": "a",
            "ấ": "a", "ầ": "a", "ẩ": "a", "ẫ": "a", "ậ": "a",
            "ă": "a", "â": "a",
            "é": "e", "è": "e", "ẻ": "e", "ẽ": "e", "ẹ": "e",
            "ế": "e", "ề": "e", "ể": "e", "ễ": "e", "ệ": "e",
            "ê": "e",
            "í": "i", "ì": "i", "ỉ": "i", "ĩ": "i", "ị": "i",
            "ó": "o", "ò": "o", "ỏ": "o", "õ": "o", "ọ": "o",
            "ố": "o", "ồ": "o", "ổ": "o", "ỗ": "o", "ộ": "o",
            "ớ": "o", "ờ": "o", "ở": "o", "ỡ": "o", "ợ": "o",
            "ô": "o", "ơ": "o",
            "ú": "u", "ù": "u", "ủ": "u", "ũ": "u", "ụ": "u",
            "ứ": "u", "ừ": "u", "ử": "u", "ữ": "u", "ự": "u",
            "ư": "u",
            "ý": "y", "ỳ": "y", "ỷ": "y", "ỹ": "y", "ỵ": "y",
            "đ": "d",
            // Uppercase
            "Á": "A", "À": "A", "Ả": "A", "Ã": "A", "Ạ": "A",
            "Ắ": "A", "Ằ": "A", "Ẳ": "A", "Ẵ": "A", "Ặ": "A",
            "Ấ": "A", "Ầ": "A", "Ẩ": "A", "Ẫ": "A", "Ậ": "A",
            "Ă": "A", "Â": "A",
            "É": "E", "È": "E", "Ẻ": "E", "Ẽ": "E", "Ẹ": "E",
            "Ế": "E", "Ề": "E", "Ể": "E", "Ễ": "E", "Ệ": "E",
            "Ê": "E",
            "Í": "I", "Ì": "I", "Ỉ": "I", "Ĩ": "I", "Ị": "I",
            "Ó": "O", "Ò": "O", "Ỏ": "O", "Õ": "O", "Ọ": "O",
            "Ố": "O", "Ồ": "O", "Ổ": "O", "Ỗ": "O", "Ộ": "O",
            "Ớ": "O", "Ờ": "O", "Ở": "O", "Ỡ": "O", "Ợ": "O",
            "Ô": "O", "Ơ": "O",
            "Ú": "U", "Ù": "U", "Ủ": "U", "Ũ": "U", "Ụ": "U",
            "Ứ": "U", "Ừ": "U", "Ử": "U", "Ữ": "U", "Ự": "U",
            "Ư": "U",
            "Ý": "Y", "Ỳ": "Y", "Ỷ": "Y", "Ỹ": "Y", "Ỵ": "Y",
            "Đ": "D"
        ]
        
        var result = ""
        for char in text {
            result.append(markMap[char] ?? char)
        }
        
        return result
    }
    
    // MARK: - Case Conversion
    
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst().lowercased()
    }
    
    private func capitalizeEachWord(_ text: String) -> String {
        return text.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    // MARK: - Utility Functions
    
    /// Check if character is Vietnamese
    func isVietnameseChar(_ char: Character) -> Bool {
        let vietnameseChars: Set<Character> = [
            "á", "à", "ả", "ã", "ạ", "ắ", "ằ", "ẳ", "ẵ", "ặ",
            "ấ", "ầ", "ẩ", "ẫ", "ậ", "ă", "â",
            "é", "è", "ẻ", "ẽ", "ẹ", "ế", "ề", "ể", "ễ", "ệ", "ê",
            "í", "ì", "ỉ", "ĩ", "ị",
            "ó", "ò", "ỏ", "õ", "ọ", "ố", "ồ", "ổ", "ỗ", "ộ",
            "ớ", "ờ", "ở", "ỡ", "ợ", "ô", "ơ",
            "ú", "ù", "ủ", "ũ", "ụ", "ứ", "ừ", "ử", "ữ", "ự", "ư",
            "ý", "ỳ", "ỷ", "ỹ", "ỵ", "đ",
            "Á", "À", "Ả", "Ã", "Ạ", "Ắ", "Ằ", "Ẳ", "Ẵ", "Ặ",
            "Ấ", "Ầ", "Ẩ", "Ẫ", "Ậ", "Ă", "Â",
            "É", "È", "Ẻ", "Ẽ", "Ẹ", "Ế", "Ề", "Ể", "Ễ", "Ệ", "Ê",
            "Í", "Ì", "Ỉ", "Ĩ", "Ị",
            "Ó", "Ò", "Ỏ", "Õ", "Ọ", "Ố", "Ồ", "Ổ", "Ỗ", "Ộ",
            "Ớ", "Ờ", "Ở", "Ỡ", "Ợ", "Ô", "Ơ",
            "Ú", "Ù", "Ủ", "Ũ", "Ụ", "Ứ", "Ừ", "Ử", "Ữ", "Ự", "Ư",
            "Ý", "Ỳ", "Ỷ", "Ỹ", "Ỵ", "Đ"
        ]
        
        return vietnameseChars.contains(char)
    }
    
    /// Count Vietnamese characters in text
    func countVietnameseChars(_ text: String) -> Int {
        return text.filter { isVietnameseChar($0) }.count
    }
}
