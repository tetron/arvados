all: api-image doc-image workbench-image warehouse-image sso-image

clean:
	-rm *-image */generated/*

# ============================================================
# Dependencies for */generated files which are prerequisites
# for building docker images.

BASE_DEPS = base/Dockerfile $(BASE_GENERATED)

API_DEPS = api/Dockerfile $(API_GENERATED)

DOC_DEPS = doc/Dockerfile doc/apache2_vhost

WORKBENCH_DEPS = workbench/Dockerfile \
                 workbench/passenger.conf \
                 $(WORKBENCH_GENERATED)

WAREHOUSE_DEPS = warehouse/Dockerfile \
                 warehouse/supervisor.conf \
                 $(WAREHOUSE_GENERATED)

SSO_DEPS = sso/passenger.conf $(SSO_GENERATED)

BASE_GENERATED = base/generated

API_GENERATED = \
        api/generated/apache2_vhost \
        api/generated/config_databases.sh \
        api/generated/database.yml \
        api/generated/omniauth.rb \
        api/generated/production.rb \
        api/generated/secret_token.rb \
        api/generated/superuser_token

API_GENERATED_IN = \
        api/apache2_vhost.in \
        api/config_databases.sh.in \
        api/database.yml.in \
        api/omniauth.rb.in \
        api/production.rb.in \
        api/secret_token.rb.in \
        api/superuser_token.in

WORKBENCH_GENERATED = \
        workbench/generated/apache2_vhost \
        workbench/generated/production.rb \
        workbench/generated/secret_token.rb

WORKBENCH_GENERATED_IN = \
        workbench/apache2_vhost.in \
        workbench/production.rb.in \
        workbench/secret_token.rb.in

WAREHOUSE_GENERATED = warehouse/generated/warehouse.conf

WAREHOUSE_GENERATED_IN = warehouse/warehouse.conf.in

SSO_GENERATED = \
        sso/generated/apache2_vhost \
        sso/generated/seeds.rb \
        sso/generated/secret_token.rb

SSO_GENERATED_IN = \
        sso/apache2_vhost.in \
        sso/seeds.rb.in \
        sso/secret_token.rb.in

$(BASE_GENERATED): config.yml
	./config.rb

$(API_GENERATED): config.yml $(API_GENERATED_IN)
	./config.rb

$(WORKBENCH_GENERATED): config.yml $(WORKBENCH_GENERATED_IN)
	./config.rb

$(WAREHOUSE_GENERATED): config.yml $(WAREHOUSE_GENERATED_IN)
	./config.rb

$(SSO_GENERATED): config.yml $(SSO_GENERATED_IN)
	./config.rb

# ============================================================
# The main Arvados servers: api, doc, workbench, warehouse

api-image: passenger-image $(API_DEPS)
	mkdir -p api/generated
	tar -c -z -f api/generated/api.tar.gz -C ../services api
	docker build -t arvados/api api
	echo -n "Built at $(date)" > api-image

doc-image: base-image $(DOC_DEPS)
	mkdir -p doc/generated
	tar -c -z -f doc/generated/doc.tar.gz -C .. doc
	docker build -t arvados/doc doc
	echo -n "Built at $(date)" > doc-image

workbench-image: passenger-image $(WORKBENCH_DEPS)
	mkdir -p workbench/generated
	tar -c -z -f workbench/generated/workbench.tar.gz -C ../apps workbench
	docker build -t arvados/workbench workbench
	echo -n "Built at $(date)" > workbench-image

warehouse-image: base-image $(WAREHOUSE_DEPS)
	docker build -t arvados/warehouse warehouse
	echo -n "Built at $(date)" > warehouse-image

sso-image: passenger-image $(SSO_DEPS)
	docker build -t arvados/sso sso
	echo -n "Built at $(date)" > sso-image

# ============================================================
# The arvados/base image is the base Debian image plus packages
# that are dependencies for every Arvados service.

passenger-image: base-image
	docker build -t arvados/passenger passenger
	echo -n "Built at $(date)" > passenger-image

base-image: debian-image $(BASE_DEPS)
	docker build -t arvados/base base
	echo -n "Built at $(date)" > base-image

debian-image:
	./mkimage-debootstrap.sh arvados/debian wheezy http://debian.lcs.mit.edu/debian/
	echo -n "Built at $(date)" > debian-image

