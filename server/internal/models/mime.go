package models

import (
	"path"
	"strings"
)

// FileCategory is the coarse grouping the client colors and badges by. It is
// resolved here, server-side, so every client agrees on what a file is.
type FileCategory string

// File categories, matching the filetype tokens in the design system.
const (
	CategoryFolder       FileCategory = "folder"
	CategoryImage        FileCategory = "image"
	CategoryVideo        FileCategory = "video"
	CategoryAudio        FileCategory = "audio"
	CategoryPDF          FileCategory = "pdf"
	CategoryDocument     FileCategory = "document"
	CategorySpreadsheet  FileCategory = "spreadsheet"
	CategoryPresentation FileCategory = "presentation"
	CategoryArchive      FileCategory = "archive"
	CategoryCode         FileCategory = "code"
	CategoryText         FileCategory = "text"
	CategoryGeneric      FileCategory = "generic"
)

var mimeByExtension = map[string]string{
	".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".gif": "image/gif",
	".webp": "image/webp", ".bmp": "image/bmp", ".tif": "image/tiff", ".tiff": "image/tiff",
	".heic": "image/heic", ".heif": "image/heif", ".svg": "image/svg+xml", ".avif": "image/avif",
	".ico": "image/vnd.microsoft.icon",

	".mp4": "video/mp4", ".m4v": "video/mp4", ".mov": "video/quicktime", ".mkv": "video/x-matroska",
	".webm": "video/webm", ".avi": "video/x-msvideo", ".mpg": "video/mpeg", ".mpeg": "video/mpeg",
	".3gp": "video/3gpp",

	".mp3": "audio/mpeg", ".m4a": "audio/mp4", ".aac": "audio/aac", ".wav": "audio/wav",
	".flac": "audio/flac", ".ogg": "audio/ogg", ".opus": "audio/opus", ".wma": "audio/x-ms-wma",

	".pdf": "application/pdf",

	".doc":   "application/msword",
	".docx":  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	".odt":   "application/vnd.oasis.opendocument.text",
	".rtf":   "application/rtf",
	".pages": "application/x-iwork-pages-sffpages",

	".xls":  "application/vnd.ms-excel",
	".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	".ods":  "application/vnd.oasis.opendocument.spreadsheet",
	".csv":  "text/csv",
	".tsv":  "text/tab-separated-values",

	".ppt":  "application/vnd.ms-powerpoint",
	".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	".odp":  "application/vnd.oasis.opendocument.presentation",

	".zip": "application/zip", ".rar": "application/vnd.rar", ".7z": "application/x-7z-compressed",
	".tar": "application/x-tar", ".gz": "application/gzip", ".bz2": "application/x-bzip2",
	".xz": "application/x-xz",

	".html": "text/html", ".htm": "text/html", ".xml": "application/xml",
	".json": "application/json", ".yaml": "application/yaml", ".yml": "application/yaml",
	".js": "text/javascript", ".ts": "text/x-typescript", ".css": "text/css",
	".go": "text/x-go", ".py": "text/x-python", ".dart": "text/x-dart",
	".java": "text/x-java", ".c": "text/x-c", ".cpp": "text/x-c++", ".h": "text/x-c",
	".rs": "text/x-rust", ".sh": "application/x-sh", ".sql": "application/sql",

	".txt": "text/plain", ".md": "text/markdown", ".log": "text/plain",
}

// MimeFromName guesses a MIME type from a filename, returning empty when the
// extension is unknown.
func MimeFromName(name string) string {
	ext := strings.ToLower(path.Ext(name))
	return mimeByExtension[ext]
}

// CategoryOf maps a node onto the badge and color the client uses.
func CategoryOf(nodeType NodeType, mimeType, name string) FileCategory {
	if nodeType == NodeFolder {
		return CategoryFolder
	}
	m := strings.ToLower(strings.TrimSpace(mimeType))
	if m == "" {
		m = MimeFromName(name)
	}
	switch {
	case m == "application/pdf":
		return CategoryPDF
	case strings.HasPrefix(m, "image/"):
		return CategoryImage
	case strings.HasPrefix(m, "video/"):
		return CategoryVideo
	case strings.HasPrefix(m, "audio/"):
		return CategoryAudio
	}
	switch m {
	case "application/msword",
		"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		"application/vnd.oasis.opendocument.text",
		"application/rtf",
		"application/x-iwork-pages-sffpages":
		return CategoryDocument
	case "application/vnd.ms-excel",
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		"application/vnd.oasis.opendocument.spreadsheet",
		"text/csv", "text/tab-separated-values":
		return CategorySpreadsheet
	case "application/vnd.ms-powerpoint",
		"application/vnd.openxmlformats-officedocument.presentationml.presentation",
		"application/vnd.oasis.opendocument.presentation":
		return CategoryPresentation
	case "application/zip", "application/vnd.rar", "application/x-7z-compressed",
		"application/x-tar", "application/gzip", "application/x-bzip2", "application/x-xz":
		return CategoryArchive
	case "text/html", "application/xml", "application/json", "application/yaml",
		"text/javascript", "text/x-typescript", "text/css", "text/x-go", "text/x-python",
		"text/x-dart", "text/x-java", "text/x-c", "text/x-c++", "text/x-rust",
		"application/x-sh", "application/sql":
		return CategoryCode
	case "text/plain", "text/markdown":
		return CategoryText
	}
	if strings.HasPrefix(m, "text/") {
		return CategoryText
	}
	return CategoryGeneric
}

// Previewable reports whether a client can render this inline rather than
// only offering a download.
func Previewable(category FileCategory) bool {
	switch category {
	case CategoryImage, CategoryVideo, CategoryAudio, CategoryPDF, CategoryText, CategoryCode:
		return true
	default:
		return false
	}
}
