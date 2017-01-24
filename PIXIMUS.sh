#!/bin/bash
<< MEMO
パラメータを色々変えながらXDSをいっぱい回してくれて嬉しいスクリプト: 略してPIXIMUS

ver4.0
検出器パラメータ自動挿入

By Hiroaki Kikuchi
2016/11/28


******必要な環境*******
Bash（shで使いたいならシェバンを書き換えること）
Python3系
Pythonモジュール: functools, texttable, numpy
XDSのxds_par（xdsでやりたいなら適宜変更）

*****必要なファイル*****
*PIXIMUS.sh
これ．本体．

*XDSINP_template.PIX
XDS.INPのテンプレート．振りたいパラメータの行は予めつくっておくこと．
（ない場合は置換でなく追加，と変更してもいいが面倒だったので）

*INPPAR.PIX
振りたいパラメータの種類，パラメータの値を書いておくファイル．
（例）
FRAME_NUMBER, 1 200, 1 100, 1 50
RESOLUTION, 50 0, 50 3
SPOT_SIZE, 3, 6, 9

*product.py
PARLIST.INPをもとにすべての組み合わせ（直積）の配列を生成するpythonスクリプト．

以上のファイルをデータセットと同じディレクトリに入れて，PIXIMUSを起動する．


******出力ファイル******
*PIXOUT_######/
XDSが走るごとに生成されるディレクトリ．

*par_product.pix
product.pyが生成する中間ファイル．すべてのパラメータの組み合わせがCSVで記載．

*DIRTABLE.PIX
PIXOUT_######/がどの組み合わせに相当するかを示す表．

*xds_#######.log
XDSのログファイル．

*ERRLIST.PIX
エラーコメントのリスト

*LATLIST.PIX
格子定数のリスト．XPARM.XDSが生成された場合のみ追記されていく．
体積で絞り込みをする．
TODO: 引数で指定できるようにする？

**********************
MEMO


# pythonスクリプトから直積とディレクトリテーブルを生成
# シェルスクリプトでやるのはつらかったので．．．
python product.py

# 行数の取得
line_num=`grep -c '' par_product.pix`
# pi
pi=$(echo "scale=10; 4*a(1)" | bc -l)

# パラメータ名のリスト取得
name_str=`sed -n 1p par_product.pix`
name_list=(`echo $name_str | tr -s ',' ' '`)
name_ind=`expr ${#name_list[@]} - 1`


for n in `seq 2 $line_num`
do
  cp XDSINP_template.PIX XDS.INP

  par_str=`sed -n "$n"p par_product.pix`
  # 区切りのスペースとパラメータで指定したいスペース（フレーム数1 360など）
  # を分けるため苦肉の策で一旦"%"に変換してる．不都合があれば他の記号にすること．
  a=(`echo $par_str | tr ' ' '%'`)
  par_list=(`echo ${a[@]} | tr ',' ' '`)

  # XDS.INPのパラメータを書き換え
  for m in `seq 0 $name_ind`
  do
    # パラメータを指定しない（コメントアウトする）場合
    if test ${par_list[$m]} = 'd' || test ${par_list[$m]} = '%d'; then
      sed -i "/${name_list[$m]}/c !${name_list[$m]}" XDS.INP

    # 指定する場合
    else
      sed -i "/${name_list[$m]}/c ${name_list[$m]}=${par_list[$m]}" \
        XDS.INP
       # %とムダなスペースを削除
      sed -i 's/%/ /g' XDS.INP
      sed -i 's/= /=/g' XDS.INP
    fi
  done

  # ディレクトリ生成
  # nを1スタートに．また0を補完して桁数を揃える．
  tmp=`expr ${n} - 1`
  N=`printf %06d ${tmp}` # 桁数はpython側と合わせること
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
    # ifでは整数値が要求されるため小数点以下カット
    V=`echo $V | cut -d. -f1`

    # 検出器パラメータの挿入
    sed '9c\    1203.718994    1181.130371     100.162270' XPARM.XDS

    # ここで体積絞り込み
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

  # 新しく生成されたファイルはすべて解析ごとのディレクトリに移動
  # ここで指定したもの以外はすべて移動されるので注意．余計なファイルは置かない．
  \ls | grep -vEe 'PIXIMUS.sh' \
             -vEe 'img$' \
             -vEe 'pix$' \
             -vEe 'PIX$' \
             -vEe 'product.py'\
             -vEe 'PIXOUT*' \
    | grep -v / | xargs mv -t ./PIXOUT_$N

done


