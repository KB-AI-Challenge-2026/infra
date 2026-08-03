#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
backend_url="${BACKEND_URL:-http://localhost:8080}"
ai_url="${AI_URL:-http://localhost:8000}"
flutter_url="${FLUTTER_URL:-http://localhost:4174}"
advisor_url="${ADVISOR_URL:-http://localhost:4173}"
fixture="${DOCUMENT_FIXTURE:-${root_dir}/aiserver/tests/fixtures/user_entered_contract.txt}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

curl --fail --silent --show-error "${ai_url}/api/v1/health/ready" >"${work_dir}/ai-health.json"
curl --fail --silent --show-error "${backend_url}/actuator/health/readiness" >"${work_dir}/backend-health.json"
curl --fail --silent --show-error "${flutter_url}/healthz" >"${work_dir}/flutter-health.txt"
curl --fail --silent --show-error "${advisor_url}/healthz" >"${work_dir}/advisor-health.txt"

curl --fail --silent --show-error \
  "${backend_url}/api/v1/users/demo-user/roadmap" \
  >"${work_dir}/roadmap.json"

curl --fail --silent --show-error \
  "${backend_url}/api/v1/advisor/customers?query=Nguyen" \
  >"${work_dir}/advisor-search.json"

curl --fail --silent --show-error \
  -F "document=@${fixture};type=text/plain" \
  -F "target_language=vi" \
  -F "external_model_consent=false" \
  -F "user_id=smoke-user" \
  "${backend_url}/api/v1/documents" \
  >"${work_dir}/upload.json"

document_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["document_id"])' "${work_dir}/upload.json")"
curl --fail --silent --show-error \
  -X POST \
  "${backend_url}/api/v1/documents/${document_id}/analyze?document_type_hint=employment_contract" \
  >"${work_dir}/analysis.json"

python3 - "${work_dir}" "${document_id}" <<'PY'
import json
import pathlib
import sys

work = pathlib.Path(sys.argv[1])
document_id = sys.argv[2]
analysis = json.loads((work / "analysis.json").read_text())
assert analysis["fields"]["monthly_salary"]["value"] == 2_400_000
assert analysis["model"]["external_data_sent"] is False
assert analysis["localization_validation"]["numbers_preserved"] is True
payload = {
    "user_id": "smoke-user",
    "message": "본국 송금과 한국 저축을 함께 준비하고 싶어요",
    "language": "vi",
    "document_ids": [document_id],
    "remittance_amount": 1_000_000,
    "saving_amount": 500_000,
    "external_model_consent": False,
}
(work / "plan-request.json").write_text(json.dumps(payload), encoding="utf-8")
PY

curl --fail --silent --show-error \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: smoke-${document_id}" \
  --data-binary "@${work_dir}/plan-request.json" \
  "${backend_url}/api/v1/agent/messages" \
  >"${work_dir}/plan.json"

python3 - "${work_dir}" <<'PY'
import json
import pathlib
import sys

work = pathlib.Path(sys.argv[1])
plan = json.loads((work / "plan.json").read_text())
assert plan["status"] == "WAITING_FOR_APPROVAL"
assert plan["sources"]
assert json.loads((work / "roadmap.json").read_text())["steps"]
assert json.loads((work / "advisor-search.json").read_text())["items"]
approval = {
    "approved_step_ids": [
        step["id"] for step in plan["steps"] if step.get("requires_approval")
    ],
    "approval_token": plan["approval_token"],
}
(work / "approval-request.json").write_text(json.dumps(approval), encoding="utf-8")
(work / "plan-id.txt").write_text(plan["plan_id"], encoding="utf-8")
PY

plan_id="$(cat "${work_dir}/plan-id.txt")"
curl --fail --silent --show-error \
  -X POST \
  -H "Content-Type: application/json" \
  --data-binary "@${work_dir}/approval-request.json" \
  "${backend_url}/api/v1/agent/plans/${plan_id}/approve" \
  >"${work_dir}/approval.json"

python3 - "${work_dir}/approval.json" <<'PY'
import json
import sys

approved = json.load(open(sys.argv[1]))
assert approved["status"] == "ACTION_PREPARED"
assert approved["next_action"] == "EXTERNAL_INTEGRATION_REQUIRED"
PY

echo "Integration smoke test passed: Flutter/React -> Spring Boot -> FastAPI -> PostgreSQL"
