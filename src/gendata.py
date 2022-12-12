import random
import argparse


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    # parser.add_argument("-a1", type=int, default=1)
    # parser.add_argument("-b1", type=int, default=100)
    # parser.add_argument("-a2", type=int, default=100)
    # parser.add_argument("-b2", type=int, default=200)
    parser.add_argument("-n1", type=int, default=100, help="number of initial nodes")
    parser.add_argument("-n2", type=int, default=100, help="number of operations")
    parser.add_argument("-f1", type=str, default="../data/listnodes.txt")
    parser.add_argument("-f2", type=str, default="../data/operations.txt")

    args=parser.parse_args()

    N1=args.n1
    fname1=args.f1
    N2=args.n2
    fname2=args.f2
    
    A1=0
    B1=N1
    A2=N1
    B2=N1+N2

    listNodes=random.sample(range(A1,B1),N1)
    with open(fname1,"w") as f:
        f.write(str(N1))
        f.write("\n")
        for num in listNodes:
            f.write(str(num))
            f.write("\n")

    opNodes=[random.choice(listNodes) for i in range(N2)]
    insertNodes=random.sample(range(A2,B2),N2)
    ops=[random.randint(0,1) for i in range(N2)]
    with open(fname2,"w") as f:
        f.write(str(N2))
        f.write("\n")
        for i in range(N2):
            # op="I" if ops[i]==1 else "R"
            op="1" if ops[i]==1 else "0"
            f.write(op)
            f.write(" ")
            f.write(str(opNodes[i]))
            # if op=="I":
            if op=="1":
                f.write(" ")
                f.write(str(insertNodes[i]))
            f.write("\n")

