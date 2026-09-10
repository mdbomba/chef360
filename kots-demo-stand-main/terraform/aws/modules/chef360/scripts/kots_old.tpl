apiVersion: kots.io/v1beta1
kind: ConfigValues
metadata:
  creationTimestamp: null
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
    configuration::addons:
      default: "0"
      value: "1"
    configuration::advanced:
      default: "0"
    configuration::deployment:
      default: configuration::deployment::principal
    configuration::experimental:
      default: "0"
    configuration::mode:
      default: configuration::mode::single
    configuration::namespace:
      value: chef-360
    dsm::isenabled:
      default: "0"
    dsm::isenabled::locked:
      value: "0"
    hab::onprem::isenabled:
      default: "0"
    keydb::ha::agent::count:
      default: "3"
      value: "3"
    keydb::ha::enabled:
      default: "0"
    keydb::ha::master::count:
      default: "1"
      value: "1"
    mailpit::http::nodeport:
      default: "31101"
      value: "31101"
    postgresql::option:
      default: postgresql::option::ha
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
      value: dslanec.chef-demo.com:31000
    primary::tenant::name:
      value: Banana Inc
    primary::tenant::ou::createDefaultSkillAssembly:
      default: "1"
    primary::tenant::ou::description: {}
    primary::tenant::ou::name:
      value: Corporate
    primary::tenant::subdomain:
      value: dslanec
    primary::tenant::tld:
      value: chef-demo.com
    progress::chef::eula:
      default: "0"
      value: "1"
    rabbitmq::amqp::nodeport:
      default: "31050"
      value: "31050"
    services::replica::authz-service::count:
      default: "1"
      value: "1"
    services::replica::bundled-tools::count:
      default: "1"
      value: "1"
    services::replica::chef-bundled-hab-packages::count:
      default: "1"
      value: "1"
    services::replica::chef-on-prem-builder::count:
      default: "1"
      value: "1"
    services::replica::chronos-service::count:
      default: "1"
      value: "1"
    services::replica::count::selector:
      default: services::replica::default
    services::replica::courier-delivery::count:
      default: "1"
      value: "1"
    services::replica::courier-orchestrator-sentry::count:
      default: "1"
      value: "1"
    services::replica::courier-scheduler-worker::count:
      default: "1"
      value: "1"
    services::replica::courier-scheduler::count:
      default: "1"
      value: "1"
    services::replica::courier-state::count:
      default: "1"
      value: "1"
    services::replica::embedded-chef-web-docs::count:
      default: "1"
      value: "1"
    services::replica::enrollment-worker::count:
      default: "1"
      value: "1"
    services::replica::experience-api::count:
      default: "1"
      value: "1"
    services::replica::internal-api-gateway::count:
      default: "1"
      value: "1"
    services::replica::license-consumption-auditor::count:
      default: "1"
      value: "1"
    services::replica::license-consumption-collector::count:
      default: "1"
      value: "1"
    services::replica::license-management::count:
      default: "1"
      value: "1"
    services::replica::license-proxy::count:
      default: "1"
      value: "1"
    services::replica::license-usage::count:
      default: "1"
      value: "1"
    services::replica::nginx-reverse-proxy::count:
      default: "1"
      value: "1"
    services::replica::node-accounts-service::count:
      default: "1"
      value: "1"
    services::replica::node-enrollment-api::count:
      default: "1"
      value: "1"
    services::replica::node-management-server::count:
      default: "1"
      value: "1"
    services::replica::notification-service::count:
      default: "1"
      value: "1"
    services::replica::public-api-gateway::count:
      default: "1"
      value: "1"
    services::replica::secret-service::count:
      default: "1"
      value: "1"
    services::replica::system-service::count:
      default: "1"
      value: "1"
    services::replica::user-accounts-service::count:
      default: "1"
      value: "1"
    smtp::auth::method:
      default: plain
    smtp::host: {}
    smtp::option:
      default: smtp::option::real
      value: smtp::option::mailpit
    smtp::password:
      value: BOOT9eGhRJeNo/pjpYkunEABKHbbVJ4gnEAT7uU=
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
    storage::option::s3::config::endpoint: {}
    storage::option::s3::config::region: {}
    storage::option::s3::config::secret::key: {}
    tenant::admin::email:
      value: donald.slanec@progress.com
    tenant::admin::name::first:
      value: Don
    tenant::admin::name::last:
      value: Slanec
status: {}