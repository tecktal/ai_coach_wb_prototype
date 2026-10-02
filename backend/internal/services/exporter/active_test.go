package exporter

import (
	"strings"
	"testing"

	"github.com/xuri/excelize/v2"
)

// The workbook must open on the analysis report. excelize activates the last
// sheet created, which put the comparison sheet in front and made the AI's
// analysis look absent.
func TestWorkbookOpensOnTheAnalysisReport(t *testing.T) {
	buf, err := GenerateAnalysisExcel(
		analysisWithSOL("clarity_and_cognitive_load"),
		testUser("Ethiopia"), testRecording(), nil,
	)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	f, err := excelize.OpenReader(strings.NewReader(string(buf.Bytes())))
	if err != nil {
		t.Fatalf("unreadable: %v", err)
	}
	defer f.Close()

	if got := f.GetSheetName(f.GetActiveSheetIndex()); got != "AI Analysis Report" {
		t.Errorf("workbook opens on %q, want \"AI Analysis Report\"", got)
	}
}
