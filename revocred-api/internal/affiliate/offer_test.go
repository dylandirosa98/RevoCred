package affiliate

import "testing"

func TestDestinations(t *testing.T) {
	for _, raw := range []string{"https://127.1/", "https://0x7f.0.0.1/", "https://0177.0.0.1/", "https://2130706433/", "https://a..example/"} {
		if ValidDestination(raw) {
			t.Errorf("accepted non-public or malformed host %q", raw)
		}
	}
	for _, raw := range []string{"http://bank.example/apply", "javascript:alert(1)", "https://user:pass@bank.example/", "https://127.0.0.1/", "https://[::1]/", "https://localhost/", "https://bank.local/", "https://bank.example:8080/", "https://bank.example/#private", "https://bank.example/\r\nLocation: other"} {
		if ValidDestination(raw) {
			t.Errorf("accepted %q", raw)
		}
	}
	if !ValidDestination("https://partner.example/apply?publisher=revocred&offer=123") {
		t.Fatal("rejected partner URL")
	}
}
