#!/bin/tcsh -f

date

echo "###################"
if (! ${?CADC_ROOT} ) then
	set CADC_ROOT = "/usr/cadc/local"
endif
echo "using CADC_ROOT = $CADC_ROOT"

if (! ${?VOSPACE_WEBSERVICE} ) then
	echo "VOSPACE_WEBSERVICE env variable not set, use default WebService URL"
else
	echo "WebService URL (VOSPACE_WEBSERVICE env variable): $VOSPACE_WEBSERVICE"
endif
if (! ${?CADC_PYTHON_TEST_TARGETS} ) then
    set CADC_PYTHON_TEST_TARGETS = 'python2.6 python2.7'
endif
echo "Testing for targets $CADC_PYTHON_TEST_TARGETS. Set CADC_PYTHON_TEST_TARGETS to change this."

echo "###################"

foreach pythonVersion ($CADC_PYTHON_TEST_TARGETS)
    echo "*************** test with $pythonVersion ************************"

    set LSCMD = "$pythonVersion $CADC_ROOT/scripts/vls"
    set MKDIRCMD = "$pythonVersion $CADC_ROOT/scripts/vmkdir"
    set RMCMD = "$pythonVersion $CADC_ROOT/scripts/vrm"
    set CPCMD = "$pythonVersion $CADC_ROOT/scripts/vcp"
    set RMDIRCMD = "$pythonVersion $CADC_ROOT/scripts/vrmdir"
    set LNCMD = "$pythonVersion $CADC_ROOT/scripts/vln"
    set CHMODCMD = "$pythonVersion $CADC_ROOT/scripts/vchmod"

    set CERT = " --cert=$A/test-certificates/x509_CADCRegtest1.pem"
    set CERT2 = " --cert=$A/test-certificates/x509_CADCAuthtest1.pem"

    echo "command: " $LNCMD $CERT
    echo

    # using a test dir makes it easier to cleanup a bunch of old/failed tests
    set VOROOT = "vos:"
    set VOHOME = "$VOROOT""CADCRegtest1"
    set BASE = "$VOHOME/atest"

    set TIMESTAMP=`date +%Y-%m-%dT%H-%M-%S`
    set CONTAINER = $BASE/$TIMESTAMP

    echo -n "** checking base URI"
    $LSCMD -v $CERT $BASE >& /dev/null
    if ( $status == 0) then
        echo " [OK]"
    else
        echo -n ", creating base URI"
            $MKDIRCMD $CERT $BASE >& /dev/null || echo " [FAIL]" && exit -1
        echo " [OK]"
    endif
    echo -n "** setting home and base to public, no groups"
    $CHMODCMD $CERT o+r $VOHOME || echo " [FAIL]" && exit -1
    echo -n " [OK]"
    $CHMODCMD $CERT o+r $BASE || echo " [FAIL]" && exit -1
    echo " [OK]"


    echo "*** starting test sequence ***"
    echo

    echo -n "create base container"
    $MKDIRCMD $CERT $CONTAINER > /dev/null || echo " [FAIL]" && exit -1
    $CHMODCMD $CERT o-r $CONTAINER > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "create container to be valid link target"
    $MKDIRCMD $CERT $CONTAINER/target > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"
     
    echo -n "copy file to target container"
    $CPCMD $CERT something.png $CONTAINER/target/something.png || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "create link to target container"
    echo $LNCMD $CERT $CONTAINER/target $CONTAINER/clink 
    $LNCMD $CERT $CONTAINER/target $CONTAINER/clink >& /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Follow the link to get the file"
    $CPCMD $CERT $CONTAINER/clink/something.png /tmp || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Follow the link without read permission and fail"
    echo $CPCMD $CERT2 $CONTAINER/clink/something.png /tmp
    $CPCMD $CERT2 $CONTAINER/clink/something.png /tmp >& /dev/null && echo " [FAIL]" && exit -1
    echo " [OK]"
     
    echo -n "create link to target file"
    $LNCMD $CERT $CONTAINER/target/something.png $CONTAINER/dlink >& /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Follow the link to get the file"
    $CPCMD $CERT $CONTAINER/dlink /tmp || echo " [FAIL]" && exit -1
    echo " [OK]"
     
    echo -n "create link to unknown authority in URI"
    $RMCMD $CERT $CONTAINER/e1link >& /dev/null
    $LNCMD $CERT vos://unknown.authority~vospace/unknown $CONTAINER/e1link >& /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Follow the invalid link and fail"
    $CPCMD $CERT $CONTAINER/e1link/somefile /tmp >& /dev/null && echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "create link to unknown scheme in URI"
    $LNCMD $CERT unknown://cadc.nrc.ca~vospace/CADCRegtest1 $CONTAINER/e2ink > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Follow the invalid link and fail"
    $CPCMD $CERT $CONTAINER/e2link/somefile /tmp  >& /dev/null && echo " [FAIL]" && exit -1
    echo " [OK]"
     
    echo -n "create link to external http URI"
    $LNCMD $CERT http://www.google.ca $CONTAINER/e3link > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"
     
    echo -n "Follow the invalid link and fail"
    $CPCMD $CERT $CONTAINER/e3link/somefile /tmp  >& /dev/null && echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "copy file to target through link"
    $CPCMD  $CERT something.png $CONTAINER/clink/something2.png || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Get the file through the link"
    $CPCMD  $CERT $CONTAINER/clink/something2.png /tmp || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "Get the file through the target"
    $CPCMD   $CERT $CONTAINER/target/something2.png /tmp || echo " [FAIL]" && exit -1
    echo " [OK]"
end

echo
echo "*** test sequence passed ***"

date
