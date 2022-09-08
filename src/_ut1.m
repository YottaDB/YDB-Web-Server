%ut1 ;VEN/SMH/JLI - CONTINUATION OF M-UNIT PROCESSING ;Aug 30, 2019@16:49
 ;;1.62;M-UNIT;;Feb 10 2020
 ; Submitted to OSEHRA Jul 8, 2017 by Joel L. Ivey under the Apache 2 license (http://www.apache.org/licenses/LICENSE-2.0.html)
 ; Original routine authored by Joel L. Ivey as XTMUNIT1 while working for U.S. Department of Veterans Affairs 2003-2012
 ; Includes addition of original COV entry and code related coverage analysis as well as other substantial additions authored by Sam Habiel 07/2013?04/2014
 ; Original by Dr. Joel Ivey
 ; Major contributions by Dr. Sam Habiel
 ; Additions and modifications made by Joel L. Ivey 05/2014-12/2015
 ; Additions and modifications made by Sam H. Habiel and Joel L. Ivey 12/2015-02/2017
 ; Modified by Christopher Edwards 08/2019
 ; 
 ; Minor changes to remove globals - Copyright (c) 2022 YottaDB LLC
 ;
 ; older comments moved to %utcover due to space requirements
 ;
 ; For a list of changes in this version in this routine see tag %ut1 in routine %utt2
 ;
 D ^%utt6 ; runs unit tests from several perspectives
 Q
 ;
 ;following is original header from XTMUNIT1 in unreleased patch XT*7.3*81 VA code
 ;XTMUNIT1    ;JLI/FO-OAK-CONTINUATION OF UNIT TEST ROUTINE ;2014-04-17  5:26 PM
 ;;7.3;TOOLKIT;**81**;APR 25 1995;Build 24
 ;
CHEKTEST(%utROU,%ut,%utUETRY,FLAG) ; Collect Test list.
 ; %utROU - input - Name of routine to check for tags with @TEST attribute
 ; %ut - input/output - passed by reference
 ; %utUETRY - input/output - passed by reference
 ; FLAG - optional - if present and true, select only !TEST entries to run
 ;
 ; Test list collected in two ways:
 ; - @TEST on labellines
 ; - Offsets of XTENT
 ;
 S %ut("ENTN")=0 ; Number of test, sub to %utUETRY.
 ;
 ; This stanza and everything below is for collecting @TEST.
 N I,J,LIST
 S FLAG=$G(FLAG,0)
 S I=$L($T(@(U_%utROU))) I I<0 Q "-1^Invalid Routine Name"
 D NEWSTYLE(.LIST,%utROU)
 I FLAG D
 . F I=1:1:LIST Q:'$D(LIST(I))  Q:LIST'>0  I $P(LIST(I),U)'="!" S LIST=LIST-1,I=I-1 Q:I=LIST  F J=I+1:1:LIST S LIST(J)=LIST(J+1) I J=LIST K LIST(J+1)
 . F I=LIST+1:1 Q:'$D(LIST(I))  K LIST(I)
 . Q
 F I=1:1:LIST S %ut("ENTN")=%ut("ENTN")+1,%utUETRY(%ut("ENTN"))=$P(LIST(I),U,2),%utUETRY(%ut("ENTN"),"NAME")=$P(LIST(I),U,3,99)
 ;
 I FLAG Q  ; don't check if only !TEST entries are selected
 ; This Stanza is to collect XTENT offsets
 N %utUI F %utUI=1:1 S %ut("ELIN")=$T(@("XTENT+"_%utUI_"^"_%utROU)) Q:$P(%ut("ELIN"),";",3)=""  D
 . N TAGNAME,FOUND S FOUND=0,TAGNAME=$P(%ut("ELIN"),";",3)
 . F I=1:1:%ut("ENTN") I %utUETRY(I)=TAGNAME S FOUND=1 Q  ; skip if already under NEW STYLE as well
 . I 'FOUND S %ut("ENTN")=%ut("ENTN")+1,%utUETRY(%ut("ENTN"))=$P(%ut("ELIN"),";",3),%utUETRY(%ut("ENTN"),"NAME")=$P(%ut("ELIN"),";",4)
 . Q
 ;
 QUIT
 ;
GETTREE(%utROU,%utULIST) ;
 ; first get any other routines this one references for running subsequently
 ; then any that they refer to as well
 ; this builds a tree of all routines referred to by any routine including each only once
 N %utUK,%utUI,%utUJ,%utURNAM,%utURLIN
 F %utUK=1:1 Q:'$D(%utROU(%utUK))  D
 . F %utUI=1:1 S %utURLIN=$T(@("XTROU+"_%utUI_"^"_%utROU(%utUK))) S %utURNAM=$P(%utURLIN,";",3) Q:%utURNAM=""  D
 . . F %utUJ=1:1:%utULIST I %utROU(%utUJ)=%utURNAM S %utURNAM="" Q
 . . I %utURNAM'="",$T(@("+1^"_%utURNAM))="" W:'$D(XWBOS) "Referenced routine ",%utURNAM," not found.",! Q
 . . S:%utURNAM'="" %utULIST=%utULIST+1,%utROU(%utULIST)=%utURNAM
 QUIT
 ;
NEWSTYLE(LIST,ROUNAME) ; JLI 140726 identify and return list of newstyle tags or entries for this routine
 ; LIST - input, passed by reference - returns containing array with list of tags identified as tests
 ;                   LIST indicates number of tags identified, LIST(n)=tag^test_info where tag is entry point for test
 ; ROUNAME - input - routine name in which tests should be identified
 ;
 N I,VALUE,LINE
 K LIST S LIST=0
 ; search routine by line for a tag and @TEST declaration
 F I=1:1 S LINE=$T(@("+"_I_"^"_ROUNAME)) Q:LINE=""  S VALUE=$$CHECKTAG(LINE) I VALUE'="" S LIST=LIST+1,LIST(LIST)=VALUE
 Q
 ;
CHECKTAG(LINE) ; JLI 170426 modified to add !TEST to checks check line to determine @test TAG
 ; LINE - input - Line of code to be checked
 ; returns null line if not @TEST line or !TEST line, otherwise TAG^NOTE
 N TAG
 S TAG=$$CHKTAGS(LINE,"@TEST") I TAG'="" Q "@"_U_TAG
 S TAG=$$CHKTAGS(LINE,"!TEST")
 I TAG'="" S TAG="!"_U_TAG
 Q TAG
 ;
CHKTAGS(LINE,TEST) ; check input LINE for TAG line, containing TEST as first test after comment
 N TAG,NOTE,CHAR
 I $E(LINE)=" " Q "" ; test entry must have a tag
 I $$UP(LINE)'[TEST Q ""  ; must have TEST declaration
 I $P($$UP(LINE),"TEST")["(" Q "" ; can't have an argument
 S TAG=$P(LINE," "),LINE=$P(LINE," ",2,400),NOTE=$P($$UP(LINE),TEST),LINE=$E(LINE,$L(NOTE)+5+1,$L(LINE))
 F  Q:NOTE=""  S CHAR=$E(NOTE),NOTE=$E(NOTE,2,$L(NOTE)) I " ;"'[CHAR Q  ;
 I $L(NOTE)'=0 Q "" ; @TEST must be first text on line
 F  Q:$E(LINE)'=" "  S LINE=$E(LINE,2,$L(LINE)) ; remove leading spaces from test info
 S TAG=TAG_U_LINE
 Q TAG
 ;
FAIL(XTERMSG) ; Entry point for generating a failure message
 ; ZEXCEPT: %utERRL,%utGUI -CREATED IN SETUP, KILLED IN END
 ; ZEXCEPT: %ut  -- NEWED ON ENTRY
 ; ZEXCEPT: XTGUISEP - newed in GUINEXT
 I $G(XTERMSG)="" S XTERMSG="no failure message provided"
 S %ut("CHK")=%ut("CHK")+1
 I '$D(%utGUI) D
 . D SETIO
 . W !,%ut("ENT")," - " W:%ut("NAME")'="" %ut("NAME")," - " W XTERMSG,! D
 . . S %ut("FAIL")=%ut("FAIL")+1,%utERRL(%ut("FAIL"))=%ut("NAME"),%utERRL(%ut("FAIL"),"MSG")=XTERMSG,%utERRL(%ut("FAIL"),"ENTRY")=%ut("ENT")
 . . I $D(%ut("BREAK")) W !,"Breaking on Failure" BREAK  ;
 . . Q
 . D RESETIO
 . Q
 I $D(%utGUI) S %ut("CNT")=%ut("CNT")+1,@%ut("RSLT")@(%ut("CNT"))=%ut("LOC")_XTGUISEP_"FAILURE"_XTGUISEP_XTERMSG,%ut("FAIL")=%ut("FAIL")+1
 Q
 ;
NVLDARG(API) ; generate message for invalid arguments to test
 N XTERMSG
 ; ZEXCEPT: %ut  -- NEWED ON ENTRY
 ; ZEXCEPT: %utERRL,%utGUI -CREATED IN SETUP, KILLED IN END
 ; ZEXCEPT: XTGUISEP - newed in GUINEXT
 S XTERMSG="NO VALUES INPUT TO "_API_"^%ut - no evaluation possible"
 I '$D(%utGUI) D
 . D SETIO
 . W !,%ut("ENT")," - " W:%ut("NAME")'="" %ut("NAME")," - " W XTERMSG,! D
 . . S %ut("FAIL")=%ut("FAIL")+1,%utERRL(%ut("FAIL"))=%ut("NAME"),%utERRL(%ut("FAIL"),"MSG")=XTERMSG,%utERRL(%ut("FAIL"),"ENTRY")=%ut("ENT")
 . . Q
 . D RESETIO
 . Q
 I $D(%utGUI) S %ut("CNT")=%ut("CNT")+1,@%ut("RSLT")@(%ut("CNT"))=%ut("LOC")_XTGUISEP_"FAILURE"_XTGUISEP_XTERMSG,%ut("FAIL")=%ut("FAIL")+1
 Q
 ;
SETIO ; Set M-Unit Device to write the results to...
 ; ZEXCEPT: %ut  -- NEWED ON ENTRY
 I $IO'=%ut("IO") S (IO(0),%ut("DEV","OLD"))=$IO USE %ut("IO") SET IO=$IO
 QUIT
 ;
RESETIO ; Reset $IO back to the original device if we changed it.
 ; ZEXCEPT: %ut  -- NEWED ON ENTRY
 I $D(%ut("DEV","OLD")) S IO(0)=%ut("IO") U %ut("DEV","OLD") S IO=$IO K %ut("DEV","OLD")
 QUIT
 ;
 ; VEN/SMH 17DEC2013 - Remove dependence on VISTA - Uppercase here instead of XLFSTR.
UP(X) ;
 Q $TR(X,"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ")
 ;
