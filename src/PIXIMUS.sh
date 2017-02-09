#!/bin/bash

usage_exit() {
    echo "hogehoge" 1>&2
    exit 1
}

while getopts d OPT
do
    case $OPT in
	d)  DO_DETECTOR=1
	    ;;
	\?) usage_exit
	    ;;
    esac
done



# Make direct product by python. 
python product.py

# Get the number of lines(=direct product).
line_num=`grep -c '' par_product.pix`
# pi
pi=$(echo "scale=10; 4*a(1)" | bc -l)

# Get list of parameter names.
name_str=`sed -n 1p par_product.pix`
name_list=(`echo $name_str | tr -s ',' ' '`)
name_ind=`expr ${#name_list[@]} - 1`


for n in `seq 2 $line_num`
do
  cp XDSINP_template.PIX XDS.INP

  par_str=`sed -n "$n"p par_product.pix`
  # Distinguish spaces for separation and spaces which XDS.INP needs.
  # ex. DATA RANGE=1 180
  # TODO: not cool.
  a=(`echo $par_str | tr ' ' '%'`)
  par_list=(`echo ${a[@]} | tr ',' ' '`)

  # Edit input parameters of XDS.INP
  for m in `seq 0 $name_ind`
  do
    # When do not set a parameter in INPPAR.PIX
    if test ${par_list[$m]} = 'd' || test ${par_list[$m]} = '%d'; then
      sed -i "/${name_list[$m]}/c !${name_list[$m]}" XDS.INP

    # When set a parameter.
    else
      sed -i "/${name_list[$m]}/c ${name_list[$m]}=${par_list[$m]}" \
        XDS.INP
       # Delete % and extra spaces.
      sed -i 's/%/ /g' XDS.INP
      sed -i 's/= /=/g' XDS.INP
    fi
  done

  # Make directories.
  # Need to match figure length with it in product.py.
  tmp=`expr ${n} - 1`
  N=`printf %06d ${tmp}`
  mkdir PIXOUT_$N
  xds_par | tee xds_$N.log

  # error list
  echo "*PIXOUT_$N" >> ERRLIST.PIX
  grep -e "!!!" xds_$N.log >> ERRLIST.PIX
  echo -e "\n" >> ERRLIST.PIX

  # lattice list
  if [ -e XPARM.XDS ]; then
    lat_str=`sed -n 4p XPARM.XDS`
    lat_list=(`echo $lat_str | tr -s ',' ' '`)
    cosa=$(echo "c(${lat_list[4]} * $pi / 180)" | bc -l)
    cosb=$(echo "c(${lat_list[5]} * $pi / 180)" | bc -l)
    cosc=$(echo "c(${lat_list[6]} * $pi / 180)" | bc -l)
    V=$(echo "sqrt(${lat_list[1]}^2 * ${lat_list[2]}^2 * ${lat_list[3]}^2 * \
      (1 + 2 * $cosa * $cosb * $cosc - $cosa^2 - $cosb^2 - $cosc^2))" | bc -l)
    # if statement requires integer.
    V=`echo $V | cut -d. -f1`

    # Replace detector parameters in XPARM.XDS.
    if [ $DO_DETECTOR == 1 ]; then
	detector=`sed -n 1p DETECTPAR.PIX`
	detector_list=(`echo $detector | tr -s ',' ' '`)
	sed -i "9c\    ${detector_list[0]}    ${detector_list[1]}    ${detector_list[2]}" XPARM.XDS
	echo 'hogehogehogehogehoge'
    fi

    # Filtering by lattice volume.
    if [ $V -gt 50000 -a $V -lt 130000 ]; then
      echo "*PIXOUT_$N" >> LATLIST.PIX
      sed -n 4p XPARM.XDS >> LATLIST.PIX
      echo -e "\n" >> LATLIST.PIX

      # DEFPIX, INTEGRATE, CORRECT
      if [ ! -e DEFPIX.LP ]; then
        sed -i "/JOB=/c JOB=DEFPIX INTEGRATE CORRECT" XDS.INP
        xds_par | tee dic_$N.log
        # error list
        echo "*PIXOUT_$N" >> ERRLIST_DIC.PIX
        grep -e "!!!" dic_$N.log >> ERRLIST_DIC.PIX
        echo -e "\n" >> ERRLIST_DIC.PIX
      fi
    fi
  fi

  # lattice list after CORRECT
  if [ -e GXPARM.XDS ]; then
    echo "*PIXOUT_$N" >> LATLIST_COR.PIX
    sed -n 4p GXPARM.XDS >> LATLIST_COR.PIX
    echo -e "\n" >> LATLIST_COR.PIX
  fi

  # Move outputs from XDS.
  \ls | grep -vEe 'PIXIMUS.sh' \
             -vEe 'img$' \
             -vEe 'pix$' \
             -vEe 'PIX$' \
             -vEe 'product.py'\
             -vEe 'PIXOUT*' \
    | grep -v / | xargs mv -t ./PIXOUT_$N

done


