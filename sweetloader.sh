#!/bin/bash

# a simple and dirty script to download
# manga from mangapoisk.ru
# REQUIREMENTS:
# awk, grep, sed, curl, printf


function setPath(){
	log="$downFolder"/"log.txt"
	tmpFolder="$downFolder"/"tmp"
	tmpFile="$tmpFolder"/"$downFolder.tmp"
	baseFolder="$downFolder"/"base"
	baseFile="$baseFolder"/"base"
	mainFile="$downFolder"/"main.html"
	htmlFolder="$downFolder"/"html"

	# hardcoded to htmlMaker function
	# touch it if you know, what you do ;-)
	imgFolder="$downFolder"/"img"

	# add somw colors for html.
	# i put it here to find it easy.
	if [ "$header" == "HTML maker:" ]
	then
		bgrdClr="#1e1f28"
		fontClr="#9BAEC8"
	fi
}


function showHeader(){
	# header will fill up according to progress
	clear
	printf "%s\n" "$header"

	[ "$downFolder" != "" ] && printf "\nDownload Folder: %s\n" "$downFolder"
	[ "$url" != "" ] && printf "Manga from URL: %s\n" "$url"
	[ "$firstLastMsg" != "" ] && printf "Chapter to start: %s\nChapter to finish: %s\n" $firstChapter "$lastChapter"
	[ "$dataBaseMsg" != "" ] && printf "$dataBaseMsg\n"
	[ "$dataPrepareMsg" != "" ] && printf "$dataPrepareMsg\n"
	[ "$imgDownloadMsg" != "" ] && printf "$imgDownloadMsg"
	[ "$htmlMsg" != "" ] && printf "$htmlMsg"

	printf "\n"
}


function askUrl(){
	# function to get URL to start work
	while [ "$url" == "" ]
	do
		showHeader
		echo -e "EXAMPLE of URL:\n\n\"https://mangapoisk.ru/manga/sweet-home-hwang-youngchan/chapter/1-\"\n"
		[ "$errorMsg" != "" ] && printf "\e[31m%s\e[0m\n" "$errorMsg"
		read -p "Enter a URL to start download: " url
		[ "$url" == "" ] && errorMsg="URL cannot be empty"
	done
}


function askFolder(){
	# function to ask folder name and create it if needed
	while [ "$downFolder" == "" ]
	do
		showHeader
		read -p "How to name download folder?: " "downFolder"
	done
	# make directory
	if  [ -d "$downFolder" ]
	then
		showHeader
		echo "Selected Directory exist. Clean everything inside? (Y)es (N)o"
		read confirm
		if [[ "$confirm" == [Yy] ]]
		then
			rm "$downFolder"/* -rf
		fi
	fi
}


function startStop(){
	# function to loop ask start and stop digits
	# TODO:
	# make checks more beauty. It is very bad now.

	# this var i use to show message in the header
	firstLastMsg=""

	while [ "$downChapter" == "" ]
	do
		showHeader
		[ "$errorMsg" == "" ] || printf "\e[31m%s\e[0m\n" "$errorMsg"
		read  -p "Start from and finish to chapter(EXAMPLE: 22, 22-140): " downChapter

		[ "$downChapter" == "" ] && ( errorMsg="Range cannot be empty." ; startStop)
		# check needed to ensure entered data is "22", "22-24", "22 24"
	if [[ "$downChapter" =~ ([0-9]{1,4}-[0-9]{1,4})|(^[0-9]{1,4}$|^[0-9]{1,4}\ [0-9]{1,4}$) ]]
	then
		firstChapter=`echo $downChapter | awk '{gsub ("-"," ",$0); print $1}' `
		lastChapter=`echo $downChapter | awk '{gsub ("-"," ",$0); print $2}'`
		[[ "$lastChapter" == "" ]] && lastChapter=$firstChapter

		if (( $firstChapter > $lastChapter  ))
		then
			errorMsg="Last chapter cannot be less than First"
			downChapter=""
			startStop
		fi
		errorMsg=""
		firstLastMsg="true"
		break
	else
		errorMsg="Use EXAMPLE, plz!"
		downChapter=""
	fi
	done
}


function reDownload(){
	# try to download page if something wrong
	retryURL="$1"
	objName="$2"
	for try in {1..10}
	do
		curl -Ls "$retryURL" > "$tmpFile"
		checkSuccess="$?"
		if 	[ "$checkSuccess" -eq 0 ]
		then
			mv "$tmpFile" "$objName"
			printf "%s download OK\n" "$objName" >> "$log"
			fileDownloaded="true"
			break
		else
			printf "%s download FAIL %s try\n" \
				"$objName" "$try" >> "$log"
		fi
	done
}


function imgDownloading(){
	# function to finally download images from dataBaseFile
	printf "\nImage Downloading started.\n" >> "$log"

	chapters=$firstChapter
	okCounter=0
	failCounter=0

	imgDownloadMsg=$(printf "\nImage Downloading is in progress:\nDownloaded: %s of %s.\nFailed %s\n" \
		"$okCounter" "$pagesToDownload" "$failCounter")
	showHeader

	while [ "$chapters" -le  "$lastChapter" ]
	do
		# ch will be used to simplify reading
		ch=$(printf "%0*d" 3 $chapters)

		# pages - array from dataBase
		pages=( $(grep "$ch:" "$baseFile"  | awk '{print $2}') )

		# if no any pages in datebase with index 001, 002, etc all steps will be skipped
		# else checked, if "$imgFile" exist.
		# if yes, it will be counted as downloaded
		# else, try to download it and redownload if failed.
		if [ ${#pages[@]} -ne 0 ]
		then
			for pgs in ${!pages[@]}
			do
				#read
				fileDownloaded="false"
				pg=$(printf "%0*d.jpg" 3 $(( pgs + 1 )))
				imgFile="$imgFolder"/ch"$ch"pg"$pg"

				if [ -f "$imgFile" ]
				then
					fileDownloaded="true"
					printf "%s existed OK\n" "$imgFile" >> "$log"
				else
					reDownload "${pages[$pgs]}" "$imgFile"
				fi

				# check file downloaded or not
				$fileDownloaded && \
					(( okCounter = okCounter + 1 )) || \
					(( failCounter = failCounter + 1 ))

				imgDownloadMsg=$(printf "\nImage Downloading is in progress:\nDownloaded: %s of %s.\nFailed %s\n" \
					"$okCounter" "$pagesToDownload" "$failCounter")
				showHeader
			done
		else
			printf "No URL in dataBase for chapter %s\n" "$ch" >> $log
		fi
		(( chapters =  chapters + 1 ))
	done

	# show final result
	printf "%s\n" "$imgDownloadMsg" >> "$log"
	imgDownloadMsg="$(printf "\nImage downloading finished.\nDownloaded: %s of %s.\nFailed %s" \
		"$okCounter" "$pagesToDownload" "$failCounter")"
	showHeader
}


function dataBasePreparing(){
	# function to put image link in one file
	printf "\nDateBase preparing started.\n" >> "$log"

	# start new dataBase file
	printf "DateBase prepared to download manga:\n" > "$baseFile"

	chapters=$firstChapter
	pagesToDownload=0

	dataPrepareMsg=$(printf "\nDateBase preparing is in progress:\nTotally to download: %s\n" $pagesToDownload)
	showHeader

	while [ "$chapters" -le "$lastChapter" ]
	do

		dateBaseName="`printf ""$baseFolder"/"$downFolder-"%0*d.html" 3 $chapters`"
		printf "\nChapter %0*d\n" 3 $chapters >> "$baseFile"
		if 	[ -f "$dateBaseName" ]
		then

			# assign URL found in downloaded file to array
			pages=( $(grep "data-alternative" "$dateBaseName" |\
				sed "s/.*data-alternative=//g;\
				s/\"//g") )

			# loop to put URL to images in format
			# <ch>: <url>
			for pgs in ${!pages[@]}
			do
				printf "%0*d: %s\n" 3 $chapters "${pages[pgs]}" >> "$baseFile"
			done

			pagesToDownload=$(( pagesToDownload + ${#pages[@]} ))

			dataPrepareMsg=$(printf "\nDateBase preparing is in progress:\nTotally to download: %s\n" $pagesToDownload)
			showHeader
		fi
		(( chapters = chapters + 1 ))

	done

	# show final result
	printf "%s\n" "$dataPrepareMsg" >> "$log"
	dataPrepareMsg=$(printf "\nDateBase preparing finished.\nTotally to download: %s\n" $pagesToDownload)
	showHeader
}


function dataBaseDownload(){
	# function to download database
	printf "\nDateBase downloading started.\n\n" >> "$log"

	chapters=$firstChapter
	okCounter=0
	dataFailCounter=0
	baseTotalToDownload=$(( lastChapter - firstChapter + 1 ))

	dataBaseMsg="$(printf "\nDateBase downloading is in progress:\nDownloaded: %s of %s.\nFailed %s\n\n" \
		"$okCounter" "$baseTotalToDownload" "$dataFailCounter")"
			showHeader

			while  [ "$chapters" -le "$lastChapter" ]
			do
				fileDownloaded="false"
				dateBaseName="`printf ""$baseFolder"/"$downFolder-"%0*d.html" 3 $chapters`"
				dateBaseUrl="$url""$chapters"

				if 	[ -f "$dateBaseName" ]
				then
					printf "%s existed OK\n" "$dateBaseName" >> "$log"
					fileDownloaded="true"
				else
					reDownload "$dateBaseUrl" "$dateBaseName"
				fi

				# fileDownload is true or false now.
				# file loaded to tmpFile. If it downloaded succesfully,
				# It will be copied to "$base" folder with appropriate name.
				# Else - nothing will be copied from tmp.

				$fileDownloaded && \
					(( okCounter = okCounter + 1 )) || \
					(( dataFailCounter = dataFailCounter + 1 ))

				dataBaseMsg="$(printf "\nDateBase downloading is in progress:\nDownloaded: %s of %s.\nFailed %s\n\n" \
					"$okCounter" "$baseTotalToDownload" "$dataFailCounter")"
				showHeader
				(( chapters =  chapters + 1 ))

			done

	# show final result
	printf "$dataBaseMsg\n" >> "$log"
	dataBaseMsg="$(printf "\nDateBase downloading finished.\nDownloaded: %s of %s.\nFailed %s\n\n" \
		"$okCounter" "$baseTotalToDownload" "$dataFailCounter")"
	showHeader
}


function askToProceed(){
	# this function to ask you to proceed with entered data
	showHeader
	printf "Are you sure to continue with Entered Data?\n"
	read  -p "(Y)es, (R)eenter, (E)xit: " confirm
	if [[ "$confirm" == [Yy] ]]
	then
		# make dirs and subdirs, and start log
		setPath
		mkdir -p {"$baseFolder","$tmpFolder","$imgFolder"}
		echo -e "$(date +%c)\nManual mode chosen\n" > "$log"
		echo "URL: $url" >> "$log"
		echo "Download folder: $downFolder" >> "$log"
		printf "Start from chapter: %s\nStop on chapter: %s\n" $firstChapter $lastChapter >> "$log"
	elif [[ "$confirm" == [Rr] ]]
	then
		manualLoader
	else
		clear
		echo "Cheers!"
		exit 1
	fi
}


function ifFail(){
	# function will ask you to repeat if something was wrong
	if [[ $dataFailCounter -ne 0 || $failCounter -ne 0 ]]
	then
		showHeader
		printf "\n"
		[ "$errorMsg" == "" ] || printf "\e[31m%s\e[0m\n" "$errorMsg"

		read -p "Some file(s) were not loaded. Repeat: (Y)es, (N)o: " confirm
		if [[ "$confirm" == [Yy] ]]
		then
			dataBaseMsg=""
			dataPrepareMsg=""
			imgDownloadMsg=""
			errorMsg=""
			printf "\nSomething was wrong. User choose try to retry:\n" >> "$log"
			dataBaseDownload
			dataBasePreparing
			imgDownloading
			ifFail
		elif [[ "$confirm" == [Nn] ]]
		then
			echo "Cheeers!"
			exit 1
		else
			errorMsg="Use \"Y\" or \"N\", plz"
			ifFail
		fi
	else
		printf "\nEverything looks fine. Do you need something else?\n"
		read -p "(E)xit, (M)ain menu: " choice
		[[ "$choice" == [mM] ]] && main || 	( clear; echo "Cheeers!"; exit 1 )
	fi
}


function askFolderRetry(){
	# function to ask folder name and try to take vars from it.
	while [ "$downFolder" == "" ]
	do
		showHeader
		[ "$errorMsg" == "" ] || printf "\e[31m%s\e[0m\n" "$errorMsg"
		read -p "How to name download folder?: " "downFolder"
	done

	setPath

	if	[[ -d "$downFolder" && -s "$log" ]]
	then
		errorMsg=""
		url="$(awk '/URL:/ {print $2 }' "$log")"
		firstChapter="$(awk '/Start from chapter:/ {print $4}' "$log" )"
		lastChapter="$(awk '/Stop on chapter:/ {print $4}' "$log" )"
		firstLastMsg="true"
	else
		downFolder=""
		errorMsg="Folder doesn't exist. try another one"
		askFolderRetry
	fi
}


function body(){
	# ask to proceed with data entered
	askToProceed

	# download database to work with
	dataBaseDownload

	# put all links from previous files to one
	dataBasePreparing

	# finally... download images
	imgDownloading

	# grep log and if something is wrong, ask to redownload
	ifFail
}


function retry(){
	# try to retry previous download, using old log in chosen folder
	header="Retry"

	askFolderRetry

	body
}


function manualLoader(){
	nulifier
	# get some settings from user:
	header="Manual mode"

	# manual download header
	showHeader

	# call function to ask folder name
	askFolder

	# call function to ask URL
	askUrl
	errorMsg=""

	# call startStop to get first and last chapter range
	# mb later I will how to make it more beauty))
	startStop

	# "body" is the same steps for "manual" and "retry" algoritms, so i used
	# special function to call it
	body
}


function askFolderHtml(){
	# function to ask folder name and try to take vars from it.
	while [ "$downFolder" == "" ]
	do
		showHeader
		[ "$errorMsg" == "" ] || printf "\e[31m%s\e[0m\n" "$errorMsg"
		read -p "How to name download folder?: " "downFolder"
	done

	setPath

	# if there is no img folder, user can exit if enter "E"
	if [[ "$downFolder" == [eE] ]]
	then
		errorMsg=""
		main
	elif [ ! -d "$downFolder" ]
	then
		errorMsg="Folder "$downFolder" doesn't exist. Try another one."
		downFolder=""
		askFolderHtml
	elif [ ! -d "$imgFolder" ]
	then
		errorMsg="There is no "$imgFolder" folder inside "$downFolder""
		downFolder=""
		askFolderHtml
	fi
}


function makeHtmls(){
	# function to make htmls for every chapter downloaded
	chapter=$firstChapter

	while [ $chapter -le $lastChapter ]

	do
		toPrint=""
		stringes=()
		iNumber=$(printf "%0*d" 3 $chapter)
		fileName="$htmlFolder/chapter$iNumber.html"
		pages=( $(ls "$imgFolder" | grep "ch$iNumber") )
		prevChapter=$(printf "%0*d" 3 $(( chapter - 1 )) )
		nextChapter=$(printf "%0*d" 3 $(( chapter  + 1 )) )

		# if chapterNumber is not equal with first and last chapter, we will print:
		if [[ $chapter -ne $firstChapter && $chapter -ne $lastChapter ]]

		then
			linkToPrint="$(printf "<p>\n\
		<u><a href=\"../html/chapter%s.html\" >PREV</a></u>\n\
		<u><a href=\"../main.html\" >MAIN</a></u>\n\
		<u><a href=\"../html/chapter%s.html\">NEXT</a></u>\n\
	</p>\n"\
				$prevChapter $nextChapter)"

		# if chapterNumber equal with firstChapter,
		# there is no previous chapter, so wi will print:
		elif [ $chapter -eq $firstChapter ]
		then
			linkToPrint="$(printf "<p>\n\
		<u><a href=\"../main.html\" >MAIN</a></u>\n
		<u><a href=\"../html/chapter%s.html\">NEXT</a></u>\n
</p>\n"\
				$nextChapter )"

		else
			linkToPrint="$(printf "<p>\n\
		<u><a href=\"../html/chapter%s.html\" >PREV</a></u>\n\
		<u><a href=\"../main.html\" >MAIN</a></u>\n\
	</p>\n"\
				$prevChapter )"
		fi

	# this text will be inserted to the beginning of file
		toPrint="$(printf "<?xml version\=\"1.0\" encoding=\"UTF-8\"?\>\n\
<html>\n\
	<head><title>chapter%s</title></head>\n\
	<body style=\"text-align: center; background-color: %s; color: %s;\">\n\
		<h4>chapter%s</h4>"\
			$iNumber  $bgrdClr $fontClr $iNumber)"
	# we add links "PREV--MAIN--NEXT"
	# after begining...
		toPrint=$(printf "%s\n\t%s\n"  "$toPrint" "$linkToPrint")

	# pages=( $(ls "$imgFolder" | grep "ch$iNumber") )
	# if there is no pictures in the folder with indexiNumber
	# for example, "ch004*" is absent, array "pages" will have zero indices.
	# so we will paste links to images, if images exists only
	# else we will paste a plug
		if [ ${#pages[@]} -ne 0 ]
		then
			for pgs in ${!pages[@]}
			do
				pgNumber=$(printf "%0*d" 3 "$(( pgs + 1 ))")

				# TODO:
				# remove hardcode "img"
				# change it with var...
				# html knowledge required ;-)
				stringes[$pgs]='<p><img src="../img/ch'$iNumber'pg'$pgNumber'.jpg"/></p>'
			done
			toPrint="$toPrint"$(printf "\n\t\t%s" "${stringes[@]}" )
		else
			toPrint="$toPrint""$(printf "\n\t\t<p>There was no pictures for this chapter</p>")"
		fi

		toPrint="$toPrint""$(printf "\n\t%s\n\t</body>\n</html>" "$linkToPrint" )"
		echo "$toPrint" > "$htmlFolder"/chapter"$iNumber".html

		htmlMsg="$(printf "\nHTML making is in progress:\nDone: %s of %s.\n\n"\
			$chapter $(( lastChapter + 1 )) )"
		showHeader

		(( chapter ++ ))
	done

	htmlMsg="$(printf "\nHTML making finished:\nDone: %s of %s.\n\n"\
		$chapter $(( lastChapter + 1 )) )"
}


function makeMain(){
	# this function will work only if
	# html are inside html folder.

	htmls=( $(ls "$htmlFolder" | grep "chapter.*.html") )

	if [ ${#htmls[@]} -ne 0 ]
	then

	chapter=$firstChapter
	mainToPrint="$(printf "<?xml version\=\"1.0\" encoding=\"UTF-8\"?\>\n\
<html>
	<head><title>%s</title></head>
	<body style=\"text-align: center; background-color: #1e1f28; color: #9BAEC8;\">\
		<h4>%s</h4>\n" "$downFolder" "$downFolder")"

	while [ $chapter -le $lastChapter ]
	do
		link=""
		for i in {1..15}
			do
				if [ $chapter -le $lastChapter ]
				then
					iNumber=$(printf "%0*d" 3 $chapter)
					[ "$link" != "" ] && \
					link=$(printf "%s\n\t<u><a href=\"html/chapter%s.html\">%s</a></u>\n"\
						"$link" "$iNumber" "$iNumber") || \
					link=$(printf "\t<u><a href=\"html/chapter%s.html\">%s</a></u>\n"\
						"$iNumber" "$iNumber")
				else
					break
				fi
			(( chapter ++ ))
		done
			link="$(printf "<p>\n%s\n</p>" "$link" )"
			mainToPrint="$(printf "%s\n%s\n"  "$mainToPrint" "$link")"
	done

	printf "%s\n</body>\n</html>\n" "$mainToPrint" >  "$mainFile"
	else
		echo "No any chapters ready for this manga("
	fi
}


function htmlMaker(){
	# get some settings from user:
	header="HTML maker:"
	nulifier

	askFolderHtml
	# create folder for html
	[ -d "$htmlFolder" ] || mkdir -p "$htmlFolder"

	# calculate how many steps will be.
	# also needed to paste "first" and "last chapters"

	# take all chapters, which has 001 page in one arrow.
	# "ls" sort file automatically
	# first chapter (the lowest) will be the first
	# the last (the biggest) will be the last
	pictures=( $(ls "$imgFolder" | grep -E "pg001.*") )
	echo "$imgFolder"
	firstChapter=$(echo ${pictures[0]} | sed -E "s/ch//;s/pg.*//")
	lastChapter=$(echo ${pictures[$(( ${#pictures[@]} - 1 )) ]} | sed -E "s/ch//;s/pg.*//")

	# make html for every chapter.
	# I know nothing about html...
	makeHtmls

	# make "main.html"
	# to acces all previous htmls
	makeMain

	showHeader
	[ "$errorMsg" != "" ] && printf "\e[31m%s\e[0m\n" "$errorMsg"
	printf "\nHTML have been made. Do you need something else?\n\n\
(M)ain menu\n(E)xit\n\n"
	read -p "Enter your choice: " firstChoice
		case $firstChoice in
		[mM])main;;
		[eE])clear; echo -e "\nsweetloader sad Bye-bye!" && exit 1;;
		*)	htmlMaker;;
	esac
}


function nulifier(){

	errorMsg=""
	url=""
	downFolder=""
	firstChapter=""
	lastChapter=""
	firstLastMsg=""
	downChapter=""
	dataBaseMsg=""
	dataPrepareMsg=""
	imgDownloadMsg=""
	htmlMsg=""
}


function main(){
	nulifier
	header="Main menu:"
	downFolder=""
	showHeader
	printf "Choose what you need:\n\n(R)etry previous download\n\
(M)anual Download\n(H)tmlMaker\n(E)xit\n\n"

	[ "$errorMsg" != "" ] && printf "\e[31m%s\e[0m\n" "$errorMsg"
	read -p "Enter your choice: " firstChoice

	case $firstChoice in
		[rR])errorMsg=""; retry;;
		[mM])errorMsg=""; manualLoader;;
		[hH])errorMsg=""; htmlMaker;;
		[eE])errorMsg=""; clear; echo -e "\nsweetloader sad Bye-bye!" && exit 1;;
		*) errorMsg="Use hint, plz"; main;;
	esac
}


clear
main

