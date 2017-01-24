# coding: utf-8
import csv
from functools import reduce
import texttable
import numpy as np

csv_obj = csv.reader(open("INPPAR.PIX", "r"))
data = [ v for v in csv_obj]

parameter_names = []
for i in range(len(data)):
  parameter_names.append(data[:][i][0])
  del data[:][i][0]
parameter = data

# 直積の生成する関数．itertablesでは行列ではなくリストを複数渡す必要があったので．
def direct_product(lists):
    return reduce(
        lambda prod, list: [x + [y] for x in prod for y in list],
        lists, [[]])

parameter_product = direct_product(parameter)

# CSVに出力=>シェルスクリプトへ
writer = csv.writer(open('par_product.pix', 'w'),
  lineterminator='\n')
writer.writerow(parameter_names)
writer.writerows(parameter_product)


# シェルスクリプトで生成されるディレクトリがどの場合に相当するかを示す表を作成
parameter_table = ['dir_num']
for i in parameter_names:
  parameter_table.append(i)

dtype = []
align = []
width = []
for i in range(len(parameter_table)):
  dtype.append('t')
  align.append("l")
  width.append(7)
#print(dtype)

parameter_table = np.array([parameter_table])

dir_index = []
for i in range(len(parameter_product)):
  dir_index.append([str("%06d" % (i + 1))])

#print(parameter_table)

parameter_table = np.r_[parameter_table, np.c_[dir_index, parameter_product]]

table = texttable.Texttable()
table.set_cols_dtype(dtype)
table.set_cols_align(align)
table.set_cols_width(width)
table.add_rows(parameter_table)
with open('DIRTABLE.PIX', 'w') as f:
  f.write(table.draw())
