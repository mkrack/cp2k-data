PROGRAM cpmd_to_qs

! Purpose: Convert the output file XX of the program pseudo.x for the
!          generation of Goedecker-Teter-Hutter (GTH) pseudo potentials which
!          is written in CPMD-format to the Quickstep potential database
!          format.

! History: - Creation (12.12.2003,MK)

! *****************************************************************************

  IMPLICIT NONE

  INTEGER, PARAMETER :: wp = SELECTED_REAL_KIND(14,200),&
                        maxl = 3,&    ! Max. angular momentum quantum number
                        max_ppl = 4,& ! Max. number of local projectors
                        max_ppnl = 4  ! Max. number of non-local projectors

  CHARACTER(LEN=200) :: input_file1,input_file2,line,output_file
  CHARACTER(LEN=17)  :: fmtstr1
  CHARACTER(LEN=16)  :: fmtstr3
  CHARACTER(LEN=12)  :: fmtstr2,string,xc_string
  REAL(KIND=wp)      :: rloc,q,z,zeff
  INTEGER            :: i,idigits,ippnl,istat,iz,j,l,n,narg,ncore,nelec,nppl,&
                        nppnl_max,nvalence,xc_code

  CHARACTER(LEN=2), DIMENSION(103) :: elesym =&
    (/"H ","He","Li","Be","B ","C ","N ","O ","F ","Ne","Na","Mg","Al","Si",&
      "P ","S ","Cl","Ar","K ","Ca","Sc","Ti","V ","Cr","Mn","Fe","Co","Ni",&
      "Cu","Zn","Ga","Ge","As","Se","Br","Kr","Rb","Sr","Y ","Zr","Nb","Mo",&
      "Tc","Ru","Rh","Pd","Ag","Cd","In","Sn","Sb","Te","I ","Xe","Cs","Ba",&
      "La","Ce","Pr","Nd","Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb",&
      "Lu","Hf","Ta","W ","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po",&
      "At","Rn","Fr","Ra","Ac","Th","Pa","U ","Np","Pu","Am","Cm","Bk","Cf",&
      "Es","Fm","Md","No","Lr"/)

  REAL(KIND=wp), DIMENSION(max_ppl)      :: cppl
  REAL(KIND=wp), DIMENSION(max_ppnl)     :: rppnl
  REAL(KIND=wp), DIMENSION(max_ppnl,3,3) :: cppnl

  INTEGER, DIMENSION(max_ppnl) :: nppnl
  INTEGER, DIMENSION(maxl+1)   :: elec_conf

  INTEGER :: iargc

! -----------------------------------------------------------------------------

  input_file1 = ""
  input_file2 = ""
  output_file = ""

  z = 0.0_wp
  zeff = 0.0_wp

  nppnl(:) = 0

  cppl(:) = 0.0_wp
  rppnl(:) = 0.0_wp
  cppnl(:,:,:) = 0.0_wp

! *** Check the number of arguments ***

  narg = iargc()
  IF (narg /= 3) THEN
    PRINT*,"ERROR: Expected three valid file names as arguments, found",narg
    PRINT*,"       <input_file1> <input_file2> <output_file>"
    PRINT*,"       e.g. XX atom.dat QS"
    STOP
  END IF

! *** Open I/O units ***

  CALL getarg(1,input_file1)
  OPEN (UNIT=1,&
        FILE=TRIM(input_file1),&
        STATUS="OLD",&
        ACCESS="SEQUENTIAL",&
        FORM="FORMATTED",&
        POSITION="REWIND",&
        ACTION="READ",&
        IOSTAT=istat)
  IF (istat /= 0) THEN
    PRINT*,"ERROR: Could not open the first input file "//TRIM(input_file1)
    STOP
  END IF

  CALL getarg(2,input_file2)
  OPEN (UNIT=2,&
        FILE=TRIM(input_file2),&
        STATUS="OLD",&
        ACCESS="SEQUENTIAL",&
        FORM="FORMATTED",&
        POSITION="REWIND",&
        ACTION="READ",&
        IOSTAT=istat)
  IF (istat /= 0) THEN
    PRINT*,"ERROR: Could not open the second input file "//TRIM(input_file2)
    STOP
  END IF

  CALL getarg(3,output_file)
  OPEN (UNIT=3,&
        FILE=TRIM(output_file),&
        STATUS="REPLACE",&
        ACCESS="SEQUENTIAL",&
        FORM="FORMATTED",&
        POSITION="REWIND",&
        ACTION="WRITE",&
        IOSTAT=istat)
  IF (istat /= 0) THEN
    PRINT*,"ERROR: Could not open the output file "//TRIM(output_file)
    STOP
  END IF

  OPEN (UNIT=4,&
        FILE="INFO",&
        STATUS="REPLACE",&
        ACCESS="SEQUENTIAL",&
        FORM="FORMATTED",&
        POSITION="REWIND",&
        ACTION="WRITE",&
        IOSTAT=istat)
  IF (istat /= 0) THEN
    PRINT*,"ERROR: Could not open the output file INFO"
    STOP
  END IF

! *** Read first input file (CPMD format) ***

  DO
    READ (UNIT=1,FMT="(A)",IOSTAT=istat) line
    IF (istat /= 0) THEN
      PRINT*,"ERROR reading the first input file "//TRIM(input_file1)
      STOP
    END IF
    IF (INDEX(line,"Z  =") > 0) THEN
      READ (UNIT=line(7:),FMT=*) z
    ELSE IF (INDEX(line,"ZV =") > 0) THEN
      READ (UNIT=line(7:),FMT=*) zeff
    ELSE IF (INDEX(line,"XC =") > 0) THEN
      READ (UNIT=line(7:),FMT=*) xc_code
    ELSE IF (INDEX(line,"&POTENTIAL") > 0) THEN
      EXIT
    END IF
  END DO

  IF (z == 0.0_wp) THEN
    PRINT*,"ERROR: Z is zero in the first input file "//TRIM(input_file1)
    STOP
  END IF
  IF (zeff == 0.0_wp) THEN
    PRINT*,"ERROR: Z(eff) is zero in the first input file "//TRIM(input_file1)
    STOP
  END IF

  SELECT CASE (xc_code)
  CASE (1312)
    xc_string = "BLYP"
  CASE (1111)
    xc_string = "BP"
  CASE (0900)
    xc_string = "PADE"
  CASE (0055)
    xc_string = "HCTH" ! CPMD version of HCTH120
  CASE (0066)
    xc_string = "HCTH93"
  CASE (0077)
    xc_string = "HCTH120"
  CASE (0088)
    xc_string = "HCTH147"
  CASE (0099)
    xc_string = "HCTH407"
  CASE (1134)
    xc_string = "PBE"
  CASE (0302)
    xc_string = "OLYP"
  CASE DEFAULT
    PRINT*,"ERROR: Invalid XC code found in the first input file "//TRIM(input_file1)
    STOP
  END SELECT

  READ (UNIT=1,FMT="(A)") line
  IF (INDEX(line,"GOEDECKER") == 0) THEN
    PRINT*,"ERROR: No keyword GOEDECKER found in the first input file "//TRIM(input_file1)
    STOP
  END IF
  READ (UNIT=1,FMT=*) nppnl_max
  READ (UNIT=1,FMT=*) rloc
  READ (UNIT=1,FMT=*) nppl,(cppl(i),i=1,nppl)
  DO ippnl=1,nppnl_max
    READ (UNIT=1,FMT=*) rppnl(ippnl),nppnl(ippnl),&
                        ((cppnl(ippnl,i,j),j=i,nppnl(ippnl)),i=1,nppnl(ippnl))
  END DO

  iz = NINT(z)
  WRITE (UNIT=4,FMT="(2(A,/,/),A,I3,/,A,I3)")&
    REPEAT("*",65),&
    " Atomic symbol                       : "//TRIM(elesym(iz)),&
    " Atomic number                       : ",iz,&
    " Effective core charge               : ",NINT(zeff)

! *** Read second input file (electronic configuration) ***

  READ (UNIT=2,FMT="(A)") string
  IF (TRIM(ADJUSTL(string)) /= TRIM(elesym(iz))) THEN
    PRINT*,"ERROR: Mismatching element symbols found in the input files"
    STOP
  END IF
  READ (UNIT=2,FMT="(A)") string
  IF (TRIM(ADJUSTL(string)) /= xc_string) THEN
    PRINT*,"ERROR: Mismatching XC functionals found in the input files"
    STOP
  END IF
  READ (UNIT=2,FMT=*) line ! dummy read
  READ (UNIT=2,FMT=*) line ! dummy read
  READ (UNIT=2,FMT=*) line ! dummy read
  READ (UNIT=2,FMT=*) ncore,nvalence
  WRITE (UNIT=4,FMT="(A,I3,/,A,I3)")&
    " Number of core states               : ",ncore,&
    " Number of valence states            : ",nvalence
  elec_conf(:) = 0
  DO i=1,nvalence
    READ (UNIT=2,FMT=*) n,l,q
    elec_conf(l+1) = elec_conf(l+1) + INT(q)
  END DO
  WRITE (UNIT=4,FMT="(A,6I3)")&
    " Electronic configuration (s,p,d,...): ",elec_conf(1:maxl)

! *** Check the electronic configuration ***

  nelec = 0

  DO i=1,maxl+1
    nelec = nelec + elec_conf(i)
    IF (nelec == NINT(zeff)) EXIT
  END DO

  IF (nelec /= NINT(zeff)) THEN
    PRINT*,"ERROR: Mismatch between Z(eff) and the electronic configuration found"
    STOP
  END IF

! *** Quickstep database format ***

  string = ""
  WRITE (UNIT=string,FMT="(I5)") nelec
  WRITE (UNIT=3,FMT="(A,1X,A)")&
    TRIM(elesym(iz)),"GTH-"//TRIM(xc_string)//"-q"//TRIM(ADJUSTL(string))

  nelec = 0
  DO i=1,maxl+1
    nelec = nelec + elec_conf(i)
    IF (nelec == NINT(zeff)) THEN
      WRITE (UNIT=3,FMT="(I5)") elec_conf(i)
      EXIT
    ELSE
      WRITE (UNIT=3,FMT="(I5)",ADVANCE="NO") elec_conf(i)
    END IF
  END DO

! *** Set output precision for the QS database files ***

  idigits = 8

  fmtstr1 = "(F15. ,I5,4F15. )"
  WRITE (UNIT=fmtstr1(6:6),FMT="(I1)") idigits
  WRITE (UNIT=fmtstr1(16:16),FMT="(I1)") idigits

  WRITE (UNIT=3,FMT=fmtstr1) rloc,nppl,(cppl(i),i=1,nppl)

  WRITE (UNIT=3,FMT="(I5)") nppnl_max
  DO ippnl=1,nppnl_max
    WRITE (UNIT=3,FMT=fmtstr1)&
      rppnl(ippnl),nppnl(ippnl),(cppnl(ippnl,1,j),j=1,nppnl(ippnl))
    fmtstr2 = "(T  ,4F15. )"
    WRITE (UNIT=fmtstr2(11:11),FMT="(I1)") idigits
    DO i=2,nppnl(ippnl)
      WRITE (UNIT=fmtstr2(3:4),FMT="(I2)") 15*i + 6
      WRITE (UNIT=3,FMT=fmtstr2) (cppnl(ippnl,i,j),j=i,nppnl(ippnl))
    END DO
  END DO

! *** Write the data set also to INFO file ***

  WRITE (UNIT=4,FMT="(/,A)")&
    " Exchange-correlation functional     : "//TRIM(xc_string)

! *** Set output precision for the CPMD INFO section ***

  idigits = 6

  fmtstr3 = "(/,F13. ,4F13. )"
  WRITE (UNIT=fmtstr3(8:8),FMT="(I1)") idigits
  WRITE (UNIT=fmtstr3(15:15),FMT="(I1)") idigits

  WRITE (UNIT=4,FMT="(/,T8,A,(9X,A2,I1,A1))",ADVANCE="NO")&
    "r(loc)",("C(",i,")",i=1,nppl)
  WRITE (UNIT=4,FMT=fmtstr3) rloc,(cppl(i),i=1,nppl)

  WRITE (UNIT=4,FMT=*)
  DO ippnl=1,nppnl_max
    IF (nppnl(ippnl) > 0) THEN
      WRITE (UNIT=4,FMT="(9X,A2,I1,A1,5X,A,I1)",ADVANCE="NO")&
        "r(",ippnl-1,")","h(i,j)^",ippnl-1
      WRITE (UNIT=4,FMT=fmtstr3)&
        rppnl(ippnl),(cppnl(ippnl,1,j),j=1,nppnl(ippnl))
      fmtstr2 = "(T  ,4F13. )"
      WRITE (UNIT=fmtstr2(11:11),FMT="(I1)") idigits
      DO i=2,nppnl(ippnl)
        WRITE (UNIT=fmtstr2(3:4),FMT="(I2)") 13*i + 1
        WRITE (UNIT=4,FMT=fmtstr2) (cppnl(ippnl,i,j),j=i,nppnl(ippnl))
      END DO
    END IF
  END DO

  WRITE (UNIT=4,FMT="(/,A,/,4(/,A),/,/,A)")&
    " Please cite:",&
    " - S. Goedecker, M. Teter, and J. Hutter,",&
    "   Phys. Rev. B 54, 1703 (1996)",&
    " - C. Hartwigsen, S. Goedecker, and J. Hutter,",&
    "   Phys. Rev. B 58, 3641 (1998)",&
    REPEAT("*",65)

END PROGRAM cpmd_to_qs
