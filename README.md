# Solidus ShipStation

[![CircleCI](https://circleci.com/gh/solidusio-contrib/solidus_shipstation.svg?style=shield)](https://circleci.com/gh/solidusio-contrib/solidus_shipstation)
[![codecov](https://codecov.io/gh/solidusio-contrib/solidus_shipstation/branch/master/graph/badge.svg)](https://codecov.io/gh/solidusio-contrib/solidus_shipstation)

This gem integrates [ShipStation](http://www.shipstation.com) with [Solidus](http://solidus.io). It
enables ShipStation to pull shipments from the system and update tracking numbers.

This integration is a fork of [spree_shipstation](https://github.com/DynamoMTL/spree_shipstation)
that adds Solidus and Rails 4.2+ compatibility.

## Installation

Add solidus_shipstation to your Gemfile:

```ruby
gem 'solidus_shipstation', github: 'solidusio-contrib/solidus_shipstation'
```

Bundle your dependencies and run the installation generator:

```shell
bin/rails generate solidus_shipstation:install
```

The installer will create a configuration initializer that you'll need to customize.

The installer will also create a migration, which is required by the API integration. If you are
going to use the XML integration, feel free to delete the migration file, as those columns won't be
used by the extension.

## Usage

This extension can integrate with ShipStation in two ways.

### XML integration

The [XML integration](https://help.shipstation.com/hc/en-us/articles/360025856192-Custom-Store-Development-Guide)
works by exposing a route in your Solidus application that generates an XML feed of all recently
created and updated shipments in your Solidus store.

#### XML integration: Configuration

In order to enable the XML integration, make sure to configure the relevant section of the
configuration initializer, and configure your ShipStation store accordingly:

- **Username**: the username defined in your configuration.
- **Password**: the password defined in your configuration.
- **URL to custom page**: `https://yourdomain.com/shipstation.xml`.

You can also configure your ShipStation store to pull the XML feed automatically on a recurring
basis, or manually by clicking the "Refresh stores" button.

There are five shipment states for an order (= shipment) in ShipStation. These states do not
necessarily align with Solidus, but you can configure ShipStation to create a mapping for your
specific needs. Here's the recommended mapping:

ShipStation description | ShipStation status | Solidus status
------------------------|--------------------|---------------
Awaiting Payment        | `unpaid`           | `pending`
Awaiting Shipment       | `paid`             | `ready`
Shipped                 | `shipped`          | `shipped`
Cancelled               | `cancelled`        | `cancelled`
On-Hold                 | `on-hold`          | `pending`

Once you've configured the XML integration in your app and ShipStation, there's nothing else you
need to do. ShipStation will

#### XML integration: Usage

There's nothing you need to do. Once properly configured, the integration just works!

#### XML integration: Gotchas

There are a few gotchas you need to be aware of:

- If you change the shipping method of an order in ShipStation, the change will not be reflected in
  Solidus and the tracking link might not work properly.
- When `shipstation_capture_at_notification` is enabled, any errors during payment capture will
  prevent the update of the shipment's tracking number.

### API integration

The [API integration](https://www.shipstation.com/docs/api/) works by calling the ShipStation API
to sync all of your shipments continuously.

Because ShipStation has very low rate limits (i.e., 40 reqs/minute at the time of writing), the
API integration does not send an API request for every single shipment update, as you would expect
from a traditional API integration.

Instead, a background job runs on a recurring basis and batches together all the shipments that need
to be created or updated in ShipStation. These shipments are then sent in groups of 100 (by default)
to ShipStation's [bulk order upsert endpoint](https://www.shipstation.com/docs/api/orders/create-update-multiple-orders/).

This allows us to work around ShipStation's rate limit and sync up to 4000 shipments/minute.

As you may imagine, this technique also comes at the expense of some additional complexity in the
implementation, but the extension abstracts it all away for you.

#### API integration: Configuration

In order to enable the API integration, make sure to configure the relevant section of the
configuration initializer. At the very least, the integration needs to know your API credentials
and store ID, but there are additional options you can configure — just look at the initializer!

#### API integration: Usage

Once you've configured the integration, you will also need to enqueue the `ScheduleShipmentSyncsJob`
on a recurring basis, to kick off the synchronization process. Because every app uses a different
background processing library, this is left up to the user.

Here's what an example with [sidekiq-scheduler](https://github.com/moove-it/sidekiq-scheduler) might
look like:

```yaml
# config/sidekiq.yml
:schedule:
  schedule_shipment_syncs:
    every: ['1m', first_in: '0s']
    class: 'SolidusShipstation::Api::ScheduleShipmentSyncsJob'
```

This will schedule the job to run every minute. This is generally a good starting point, but feel
free to adjust it as needed.

#### API integration: Gotchas

There's one possible problem you need to be aware of, when integrating via the API.

You should make sure the interval between your syncs is, on average, larger than your latency in
processing background jobs, or you are going to experience sync overlaps.

As an example, if it takes your Sidekiq process 10 seconds to execute a job from the time it's
scheduled, but you schedule a shipment sync every 5 seconds, your sync jobs will start overlapping,
making your latency even worse.

This is a problem that is faced by all recurring jobs. The solution is two-fold:

1. Monitor the latency of your background processing queues. Seriously, do it.
2. Make sure your sync interval is not too aggressive: unless you really need to, there's no point
   in syncing your shipments more often than once a minute.

## Development

### Testing the extension

First bundle your dependencies, then run `bin/rake`. `bin/rake` will default to building the dummy
app if it does not exist, then it will run specs. The dummy app can be regenerated by using
`bin/rake extension:test_app`.

```shell
bin/rake
```

To run [Standard](https://github.com/standardrb/standard)

```shell
bundle exec standardrb --fix
```

When testing your application's integration with this extension you may use its factories.
Simply add this require statement to your `spec/spec_helper.rb`:

```ruby
require 'solidus_shipstation/testing_support/factories'
```

Or, if you are using `FactoryBot.definition_file_paths`, you can load Solidus core
factories along with this extension's factories using this statement:

```ruby
SolidusDevSupport::TestingSupport::Factories.load_for(SolidusShipstation::Engine)
```

### Running the sandbox

To run this extension in a sandboxed Solidus application, you can run `bin/sandbox`. The path for
the sandbox app is `./sandbox` and `bin/rails` will forward any Rails commands to
`sandbox/bin/rails`.

Here's an example:

```
$ bin/rails server
=> Booting Puma
=> Rails 6.0.2.1 application starting in development
* Listening on tcp://127.0.0.1:3000
Use Ctrl-C to stop
```

### Updating the changelog

Before and after releases the changelog should be updated to reflect the up-to-date status of
the project:

```shell
bin/rake changelog
git add CHANGELOG.md
git commit -m "Update the changelog"
```

### Releasing new versions

Please refer to the dedicated [page](https://github.com/solidusio/solidus/wiki/How-to-release-extensions) on Solidus wiki.

## License

Copyright (c) 2013 Boomer Digital, released under the New BSD License.
