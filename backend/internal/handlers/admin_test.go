package handlers

import "testing"

func intPtr(v int) *int { return &v }

// TestAverageScores covers the shared overall-score helper, used by both the AI
// analysis path (analysis.go) and manual coach scoring (admin.go) so the two
// overalls are always computed the same way.
func TestAverageScores(t *testing.T) {
	cases := []struct {
		name   string
		scores []*int
		want   *float64
	}{
		{
			name:   "no scores provided returns nil",
			scores: []*int{nil, nil, nil},
			want:   nil,
		},
		{
			name:   "empty input returns nil",
			scores: nil,
			want:   nil,
		},
		{
			name:   "single score",
			scores: []*int{intPtr(4)},
			want:   float64Ptr(4),
		},
		{
			// The core Phase 0 behaviour: elements the model did not score must
			// not drag the average down. Before the fix, three elements were
			// forced to 1 and averaged in.
			name:   "nil scores are excluded, not counted as zero",
			scores: []*int{intPtr(4), nil, intPtr(5), nil},
			want:   float64Ptr(4.5),
		},
		{
			name:   "rounds to two decimal places",
			scores: []*int{intPtr(4), intPtr(5), intPtr(5)},
			want:   float64Ptr(4.67),
		},
		{
			name: "all nine elements scored",
			scores: []*int{
				intPtr(1), intPtr(2), intPtr(3), intPtr(4), intPtr(5),
				intPtr(1), intPtr(2), intPtr(3), intPtr(4),
			},
			want: float64Ptr(2.78),
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := averageScores(tc.scores...)

			if tc.want == nil {
				if got != nil {
					t.Fatalf("expected nil, got %v", *got)
				}
				return
			}
			if got == nil {
				t.Fatalf("expected %v, got nil", *tc.want)
			}
			if *got != *tc.want {
				t.Fatalf("expected %v, got %v", *tc.want, *got)
			}
		})
	}
}

func float64Ptr(v float64) *float64 { return &v }
