
tf-vars:
	curl \
	--header "Authorization: Bearer ${TF_TOKEN}" \
	--header "Content-Type: application/vnd.api+json" \
	--request GET \
	"https://app.terraform.io/api/v2/vars?filter%5Borganization%5D%5Bname%5D=deo&filter%5Bworkspace%5D%5Bname%5D=${TF_WORKSPACE}" | jq '.data[] | {key: .attributes.key, value: .attributes.value, sensitive: .attributes.sensitive, hcl: .attributes.hcl, category: .attributes.category}'


tf-account:
	http https://app.terraform.io/api/v2/account/details "Authorization: Bearer ${TF_TOKEN}" "Content-Type: application/vnd.api+json"


tf-workspaces:
	http https://app.terraform.io/api/v2/organizations/deo/workspaces "Authorization: Bearer ${TF_TOKEN}" "Content-Type: application/vnd.api+json"

