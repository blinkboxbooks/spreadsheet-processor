Feature: Extract zip files when delivered
	As a Content Manager
	I want Marvin to be able to process ONIX files delivered within ZIP files
	So that all the book information we are sent is processed

	Background:
		Given there is a publisher called "hachette_uk"

	Scenario Outline: A valid zip file is extracted
		Given "my_zipfile.zip" is a zip file containing "hello.<extension>"
		And the following file is uploaded:
			| filename       | folder      | permissions |
			| my_zipfile.zip | hachette_uk | 0664        |
		And the folder "hachette_uk/extracted_my_zipfile" does not exist
		When it is found by the watcher
		Then "hachette_uk/extracted_my_zipfile" is a folder
		And "hachette_uk/extracted_my_zipfile/hello.<extension>" is a file

		Examples: Extensions we care about extracting from zips
			| extension |
			| xml       |
			| onx       |
			| onix      |
			| jpg       |
			| png       |
			| XML       |
			| ONX       |
			| ONIX      |
			| JPG       |
			| PNG       |

	Scenario: The default extraction folder name is already in use
		Given "hello.xml.zip" is a zip file containing "hello.xml"
		And the following file is uploaded:
			| filename      | folder      | permissions |
			| hello.xml.zip | hachette_uk | 0664        |
		And the folder "hachette_uk/extracted_hello.xml" exists
		When it is found by the watcher
		Then a warning message is added to the log

	Scenario: Dealing with zip bombs (extracting only ONIX, jpg and epub files from zips)
		Given "droste.zip" is a zip file containing "droste.zip"
		And the following file is uploaded:
			| filename   | folder      | permissions |
			| droste.zip | hachette_uk | 0664        |
		When it is found by the watcher
		Then "hachette_uk/extracted_droste/droste.zip" is not a file
