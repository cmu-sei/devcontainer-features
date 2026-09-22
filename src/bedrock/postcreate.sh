#!/bin/bash
# Check Bedrock account access without modifying account settings.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

if ! org_has_profile aws && ! org_has_profile awsgov; then
    exit 0
fi
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [ -z "$region" ]; then
    echo "bedrock: set AWS_REGION to check account access." >&2
    exit 0
fi
if ! mode=$(AWS_MAX_ATTEMPTS=2 aws bedrock get-account-data-retention \
    --region "$region" --cli-connect-timeout 5 --cli-read-timeout 10 \
    --query mode --output text 2>&1); then
    echo "bedrock: could not read account data retention: $mode" >&2
else
    echo "bedrock: account data retention in $region is $mode (unchanged)."
    case "$mode" in
        aws_review|provider_data_share) ;;
        *) echo "bedrock: models requiring a different retention mode need account administrator provisioning." >&2 ;;
    esac
fi

if org_has_profile awsgov; then
    config="$PROFILES_DIR/awsgov/claude.json"
    if [ ! -f "$config" ]; then
        echo "bedrock: no $config; skipping model checks." >&2
        exit 0
    fi
    models=$(jq -r '.env // {} | to_entries[] |
        select(.key | test("^ANTHROPIC_DEFAULT_.*_MODEL$")) | .value' "$config" | sort -u)
    while IFS= read -r model; do
        [ -n "$model" ] || continue
        if result=$(AWS_MAX_ATTEMPTS=2 aws bedrock get-foundation-model-availability \
            --model-id "$model" --region "$region" --cli-connect-timeout 5 \
            --cli-read-timeout 10 --output json 2>&1); then
            if ! jq -e '.entitlementAvailability == "AVAILABLE" and .regionAvailability == "AVAILABLE"' \
                >/dev/null 2>&1 <<< "$result"; then
                echo "bedrock: $model needs account provisioning in $region: $result" >&2
            fi
        else
            echo "bedrock: could not check $model: $result" >&2
        fi
    done <<< "$models"
fi
