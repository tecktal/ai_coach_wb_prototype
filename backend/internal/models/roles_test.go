package models

import "testing"

// TestSelfAssignableRoleRejectsPrivilegedRoles is the security guard on
// registration.
//
// The users.role column carries "viewer" and "admin", which unlock the World
// Bank monitoring dashboard — every lesson, every teacher's name, and the
// classroom audio. Registration is unauthenticated, so if a self-declared role
// were trusted straight through, anyone could POST {"role":"admin"} and read the
// entire programme's data.
func TestSelfAssignableRoleRejectsPrivilegedRoles(t *testing.T) {
	privileged := []string{
		"admin", "viewer",
		"Admin", "ADMIN", "  admin", "admin ", // casing / padding must not slip through
	}

	for _, role := range privileged {
		t.Run(role, func(t *testing.T) {
			if got := SelfAssignableRole(role); got != RoleTeacher {
				t.Fatalf("SelfAssignableRole(%q) = %q — a privileged role was self-assignable", role, got)
			}
		})
	}
}

func TestSelfAssignableRoleAcceptsCoordinator(t *testing.T) {
	if got := SelfAssignableRole(RoleCoordinator); got != RoleCoordinator {
		t.Errorf("expected %q, got %q", RoleCoordinator, got)
	}
}

func TestSelfAssignableRoleDefaultsToTeacher(t *testing.T) {
	// Absent, empty, misspelled or otherwise unrecognised — all become teacher.
	// Unknown values are silently ignored rather than rejected, because the
	// field is optional and an older client will simply omit it.
	for _, role := range []string{"", "teacher", "Coordinator", "coordinater", "nonsense", "0"} {
		if role == RoleCoordinator {
			continue
		}
		if got := SelfAssignableRole(role); got != RoleTeacher {
			t.Errorf("SelfAssignableRole(%q) = %q, want %q", role, got, RoleTeacher)
		}
	}
}
