Introduction
============

This repository hosts code to produce data from the State Program Report,
IMLS's reporting system for Grants to States Program. Read more about
Grants to States at https://www.imls.gov/grants/grants-states.

Getting Started
===============

Researchers
-----------

### One-time Setup

You will need to install [Github Desktop](https://desktop.github.com/).

1. After it is installed, open Github Desktop.
1. Go to `File` > `Clone Repository`.
1. Select `imls-state-program-report` from the dropdown list and then select the button to clone it.
1. Select the location on your desktop where you want to place the files. Clone.
1. Close Github Desktop.

### Ongoing Access to CSV Files

1. Open Github Desktop.
1. Go to `Repository` > `Pull` to download the most recent files from this Github repository to your desktop.
1. Close Github Desktop.
1. Open Excel.
1. Go to `File` > `New Workbook`.
1. Go to `Import` > `CSV File` (Mac) or `Data` > `Get External Data` > `From Text File` (PC).
1. Select the appropriate CSV file (based on the timestamp in the file name) from the `imls-state-program-report/data` folder on your desktop.  Select the `Get Data` button to import it.
1. Follow the 3 steps in the text import wizard, selecting delimited, *comma* delimiter only (uncheck tab), and then finish.

Developers
----------

You will need to have Ruby 2.3.1 installed. [rbenv](https://github.com/rbenv/rbenv)
is the recommended method of installation.

Start by cloning this repo:

    git clone https://github.com/adhocteam/imls-state-program-report.git && cd imls-state-program-report

Next install the `Bundler` gem:

    gem install bundler

Install `tidy` as well:

    wget http://binaries.html-tidy.org/binaries/tidy-5.2.0/tidy-5.2.0-64bit.deb && sudo dpkg -i tidy-5.2.0-64bit.deb

You will also need to generate a
[Github access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/).

Finally, running the script should simply be

    GITHUB_TOKEN=your-generated-token-here bundle exec ruby convert.rb input.xml.gz

Optionally, you can run the script without Github credentials to skip uploading
the result CSV file. That usage is shown below, along with a method for running
the script against multiple files at the same time.

    find . -name "IMLS*.xml.gz" | xargs -I {} bundle exec ruby convert.rb "{}"

Docker
------

Running the script from within Docker is also supported. Start by installing
Docker according to the instructions here:

    https://www.docker.com/products/docker

Next, spin up a Docker Virtual Machine (VM) in the background with this command:

    docker run -dit -v /path/to/imls-state-program-report:/project ruby:2.3.1 imls bash

If the VM has been stopped for any reason, restart it with

    docker start imls

Connect to the new VM:

    docker exec -it imls bash

You should then be connected to a terminal running inside of the VM. You can
then run the script by doing something like this:

    cd /project && bundle exec convert.rb input.xml.gz

Make sure you've installed `tidy` as well:

    wget http://binaries.html-tidy.org/binaries/tidy-5.2.0/tidy-5.2.0-64bit.deb && dpkg -i tidy-5.2.0-64bit.deb

Testing
=======

The script has [RSpec](http://rspec.info/) unit tests. They can be run with

    bundle exec rspec
