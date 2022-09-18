import numpy as np
import pandas as pd

a=np.reshape(np.arange(24),(2,3,4))
print('a is \n', a)
print('===========')

a=np.reshape(a,(-1,4))
print('after reshape(-1,4), a is \n', a)
pd.DataFrame().to_csv('./test_pd.csv',mode='w',header=None, index=None)
pd.DataFrame(a).to_csv('./test_pd.csv',mode='a',header=None, index=None)

pd.DataFrame(a).to_csv('./test_pd.csv',mode='a',header=None, index=None)