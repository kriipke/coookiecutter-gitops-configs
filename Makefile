MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ZIP := "cookiecutter.zip"

.ONESHELL:
foo : docs/test
    echo $$(MAKEFILE_PATH) 
    echo $$(MAKEFILE_DIR) 
    cd $(D) &&
    printf '\n\npwd: %s\n' "$(pwd)"
    gobble $(<F) > ../$@
# all:
# 	@make -f $$(MAKEFILE_DIR)(MAKEFILE_DIR)src/configspy/Makefile
# build:
#     pushd .. && # Set parent directory as working directory
#     zip -r $ZIP $SOURCE_DIR --exclude $SOURCE_DIR/$ZIP --quiet && # ZIP cookiecutter
#     mv $ZIP $SOURCE_DIR/$ZIP && # Move ZIP to original directory
#     popd && # Restore original work directory
#     echo  "Cookiecutter full path: $PWD/$ZIP")
# 
# validate:
#     terraform fmt -recursive
#     terraform validate
# 
# plan:
#     terraform validate
#     terraform plan -var-file="variables.tfvars"
# 
# apply:
#     terraform apply -var-file="variables.tfvars" --auto-approve
# 
# destroy:
#     terraform destroy -var-file="variables.tfvars"
# 
# all: validate plan apply
