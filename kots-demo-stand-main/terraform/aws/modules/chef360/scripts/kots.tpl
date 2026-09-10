apiVersion: kots.io/v1beta1
kind: ConfigValues
metadata:
  name: chef-360
spec:
  values:
    api::gateway::admin::token::isenabled::public:
      default: "0"
    api::gateway::audit::enable:
      default: "1"
    api::gateway::auth::apitoken::isenabled:
      default: "0"
    api::gateway::body::limit:
      default: "10"
      value: "10"
    api::gateway::cache::enabled:
      default: "1"
    api::gateway::certificate::file: {}
    api::gateway::courier-orchestrator-worker::max-workers:
      default: "50"
      value: "50"
    api::gateway::install::admin::token: {}
    api::gateway::loglevel:
      default: info
    api::gateway::nodemanagement::maximum::checkin:
      default: "60"
      value: "60"
    api::gateway::nodemanagement::minimum::checkin:
      default: "5"
      value: "5"
    api::gateway::nodeport::nginx:
      default: "31000"
      value: "31000"
    api::gateway::private::key::file: {}
    api::gateway::private::key::signer: {}
    api::gateway::public::key::expiry:
      default: "1924905600"
      value: "1924905600"
    api::gateway::public::key::signer: {}
    api::gateway::root::cert::file: {}
    api::gateway::skip::cert::validation:
      default: "0"
    api::gateway::static::auth::token: {}
    api::gateway::tls::selector:
      default: api::gateway::disabled
    cluster_topology:
      default: hyperconverged-nonha
    configuration::addons:
      default: "0"
      value: "1"
    configuration::advanced:
      default: "0"
      value: "0"
    configuration::namespace:
      value: chef-360
    hab::onprem::isenabled:
      default: "0"
    log::storage::enable::audit::logs:
      default: "1"
    log::storage::enable::general::logs:
      default: "1"
    log::storage::minio::audit::logs::retention::period:
      default: "365"
      value: "365"
    log::storage::minio::general::logs::retention::period:
      default: "30"
      value: "30"
    log::storage::s3::audit::logs::bucket: {}
    log::storage::s3::auto::create:
      default: "0"
    log::storage::s3::general::logs::bucket: {}
    mailpit::http::nodeport:
      default: "31101"
      value: "31101"
    opensearch::option:
      default: opensearch::option::embedded
    opensearch::option::external::config::hostname: {}
    opensearch::option::external::config::password:
      value: KA5uHM32huTg7Y1k6P8sajYs144ij+HoUAcuxQ==
    opensearch::option::external::config::port:
      default: "443"
      value: "443"
    opensearch::option::external::config::protocol:
      default: https
    opensearch::option::external::config::root::ca: {}
    opensearch::option::external::config::ssl::verify:
      default: "1"
    opensearch::option::external::config::username: {}
    postgresql::option:
      default: postgresql::option::cnpg
    postgresql::option::cnpg::backup::enabled:
      default: "1"
      value: "0"
    postgresql::option::cnpg::backup::s3::access_key: {}
    postgresql::option::cnpg::backup::s3::destination: {}
    postgresql::option::cnpg::backup::s3::endpoint_ca: {}
    postgresql::option::cnpg::backup::s3::endpoint_url: {}
    postgresql::option::cnpg::backup::s3::region:
      default: us-east-1
    postgresql::option::cnpg::backup::s3::secret_key:
      value: dP/i7fkmXjd1t7nnvfwn0f0bvRaLOIimfsgTPQ==
    postgresql::option::ha::config::pg::max_connections:
      default: "3050"
      value: "3050"
    postgresql::option::ha::config::pool::maxPool:
      default: "6"
      value: "6"
    postgresql::option::ha::config::pool::numInitChildren:
      default: "500"
      value: "500"
    postgresql::option::ha::config::pool::reservedConnections:
      default: "1"
      value: "1"
    postgresql::option::ha::migration::enabled:
      default: "0"
    postgresql::option::rds::config::master::password: {}
    postgresql::option::rds::config::master::username: {}
    postgresql::option::rds::config::reader::endpoint: {}
    postgresql::option::rds::config::reader::port: {}
    postgresql::option::rds::config::replica::password: {}
    postgresql::option::rds::config::replica::username: {}
    postgresql::option::rds::config::writer::endpoint: {}
    postgresql::option::rds::config::writer::port: {}
    preflight::strict::mode:
      default: "0"
      value: "1"
    primary::tenant::direct::access:
      default: "1"
      value: "1"
    primary::tenant::fqdn:
      value: "${tenant_subdomain}.${tenant_tld}:31000"
    primary::tenant::name:
      value: "${tenant_name}"
    primary::tenant::ou::createDefaultSkillAssembly:
      default: "1"
    primary::tenant::ou::description: {}
    primary::tenant::ou::name:
      value: "${org_unit_name}"
    primary::tenant::subdomain:
      value: "${tenant_subdomain}"
    primary::tenant::tld:
      value: "${tenant_tld}"
    progress::chef::eula:
      default: "0"
      value: "1"
    rabbitmq::amqp::nodeport:
      default: "31050"
      value: "31050"
    smtp::auth::method:
      default: plain
    smtp::host: {}
    smtp::option:
      default: smtp::option::real
      value: smtp::option::mailpit
    smtp::password:
      value: rExQyVODYPFEq84jrYjThAoGQWlBmm/hFVNUzX1/o8TXG/RwFLJJJDY=
    smtp::port:
      default: "587"
      value: "587"
    smtp::retries::enabled:
      default: "0"
    smtp::retries::number:
      default: "2"
      value: "2"
    smtp::senderEmail: {}
    smtp::server::name:
      default: Default-SMTP
      value: Default-SMTP
    smtp::tls::enable:
      default: "0"
    smtp::tls::rootca: {}
    smtp::tls::skipValidation:
      default: "0"
    smtp::username: {}
    storage::option:
      default: storage::option::minio
    storage::option::s3::config::access::key: {}
    storage::option::s3::config::dsm::bucket: {}
    storage::option::s3::config::endpoint: {}
    storage::option::s3::config::region: {}
    storage::option::s3::config::secret::key: {}
    tenant::admin::email:
      value: "${admin_email}"
    tenant::admin::name::first:
      value: "${admin_first_name}"
    tenant::admin::name::last:
      value: "${admin_last_name}"
status: {}
