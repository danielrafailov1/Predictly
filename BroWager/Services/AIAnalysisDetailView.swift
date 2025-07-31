//
//  AIAnalysisDetailView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-31.
//
import SwiftUI

// MARK: - AI Analysis Detail View Components

struct AIAnalysisDetailView: View {
    let analysis: String
    let searchQuery: String
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse
            Button(action: onToggle) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("AI Analysis & Reasoning")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Search Query Section
                    if !searchQuery.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 12))
                                Text("Search Query Used")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                            
                            Text(searchQuery)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Parsed Analysis Sections
                    let parsedSections = parseAnalysisIntoSections(analysis)
                    
                    ForEach(Array(parsedSections.enumerated()), id: \.offset) { index, section in
                        AnalysisSectionView(section: section)
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Parse the AI analysis into structured sections
    private func parseAnalysisIntoSections(_ analysis: String) -> [AnalysisSection] {
        var sections: [AnalysisSection] = []
        let lines = analysis.components(separatedBy: .newlines)
        
        var currentSection: AnalysisSection?
        var currentContent: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty { continue }
            
            // Check if this is a section header
            if let sectionType = identifySectionType(trimmedLine) {
                // Save previous section if exists
                if let section = currentSection {
                    sections.append(AnalysisSection(
                        type: section.type,
                        title: section.title,
                        content: currentContent.joined(separator: "\n"),
                        icon: section.icon,
                        color: section.color
                    ))
                }
                
                // Start new section
                currentSection = AnalysisSection(
                    type: sectionType,
                    title: getSectionTitle(for: sectionType),
                    content: "",
                    icon: getSectionIcon(for: sectionType),
                    color: getSectionColor(for: sectionType)
                )
                currentContent = []
            } else {
                // Add content to current section
                currentContent.append(trimmedLine)
            }
        }
        
        // Don't forget the last section
        if let section = currentSection {
            sections.append(AnalysisSection(
                type: section.type,
                title: section.title,
                content: currentContent.joined(separator: "\n"),
                icon: section.icon,
                color: section.color
            ))
        }
        
        return sections
    }
    
    private func identifySectionType(_ line: String) -> AnalysisSectionType? {
        let upperLine = line.uppercased()
        
        if upperLine.contains("SEARCH ANALYSIS") {
            return .searchAnalysis
        } else if upperLine.contains("OPTION VERIFICATION") {
            return .optionVerification
        } else if upperLine.contains("EVIDENCE FROM SEARCH") {
            return .evidence
        } else if upperLine.contains("CONFIDENCE") {
            return .confidence
        } else if upperLine.contains("REASONING") || upperLine.contains("ANALYSIS") {
            return .reasoning
        }
        
        return nil
    }
    
    private func getSectionTitle(for type: AnalysisSectionType) -> String {
        switch type {
        case .searchAnalysis:
            return "Search Data Analysis"
        case .optionVerification:
            return "Option-by-Option Verification"
        case .evidence:
            return "Supporting Evidence"
        case .confidence:
            return "Confidence Assessment"
        case .reasoning:
            return "AI Reasoning"
        }
    }
    
    private func getSectionIcon(for type: AnalysisSectionType) -> String {
        switch type {
        case .searchAnalysis:
            return "doc.text.magnifyingglass"
        case .optionVerification:
            return "checklist"
        case .evidence:
            return "quote.bubble"
        case .confidence:
            return "gauge"
        case .reasoning:
            return "brain"
        }
    }
    
    private func getSectionColor(for type: AnalysisSectionType) -> Color {
        switch type {
        case .searchAnalysis:
            return .cyan
        case .optionVerification:
            return .blue
        case .evidence:
            return .green
        case .confidence:
            return .orange
        case .reasoning:
            return .purple
        }
    }
}

// MARK: - Analysis Section Types and Models
enum AnalysisSectionType {
    case searchAnalysis
    case optionVerification
    case evidence
    case confidence
    case reasoning
}

struct AnalysisSection {
    let type: AnalysisSectionType
    let title: String
    let content: String
    let icon: String
    let color: Color
}

struct AnalysisSectionView: View {
    let section: AnalysisSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            HStack {
                Image(systemName: section.icon)
                    .foregroundColor(section.color)
                    .font(.system(size: 13, weight: .medium))
                
                Text(section.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(section.color)
                
                Spacer()
            }
            
            // Section Content
            if section.type == .optionVerification {
                // Special formatting for option verification
                OptionVerificationContentView(content: section.content)
            } else {
                // Regular content display
                Text(section.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(section.color.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(section.color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct OptionVerificationContentView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let optionLines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            ForEach(Array(optionLines.enumerated()), id: \.offset) { index, line in
                OptionVerificationRowView(line: line)
            }
        }
    }
}

struct OptionVerificationRowView: View {
    let line: String
    
    private var statusInfo: (icon: String, color: Color) {
        extractStatus(from: line)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status Icon
            Image(systemName: statusInfo.icon)
                .foregroundColor(statusInfo.color)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 16)
            
            // Option text
            Text(line)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusInfo.color.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func extractStatus(from line: String) -> (icon: String, color: Color) {
        let upperLine = line.uppercased()
        
        if upperLine.contains("CORRECT") && !upperLine.contains("INCORRECT") {
            return ("checkmark.circle.fill", .green)
        } else if upperLine.contains("INCORRECT") {
            return ("x.circle.fill", .red)
        } else if upperLine.contains("UNCERTAIN") {
            return ("questionmark.circle.fill", .orange)
        } else {
            return ("minus.circle.fill", .gray)
        }
    }
}
