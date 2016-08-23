import java.net.*;
import java.io.*;
public class TCPForward {
	public static  OutputStream log = null;
	private static int localPort = 2008;
	private static int remotePort = 1521;
	private static String remoteHost = "192.168.0.5";
	public TCPForward(int _port,String _host,int _remotePort) {
		try{
			localPort = _port;
			remoteHost = _host;
			remotePort = _remotePort;
			log = new FileOutputStream("./result.txt");
		}catch(Exception e){
		   e.printStackTrace();			
		}
	}

	public void  createServer()throws Exception{
		Thread thread1 = new Thread(){
			public void run(){
				 try{
					   ServerSocket serverSocket = new ServerSocket(localPort);
					   int counter = 0;
					   while (true) {
						 Socket socket = serverSocket.accept();
						 Worker worker = new Worker(socket,remoteHost,remotePort,log);
						 worker.start();
					   }
				 }catch(Exception e){
					   e.printStackTrace();
				 }
			}
		};
		thread1.start();
	}
	public static void main(String[] args)throws Exception {
		if(args.length<3){
			System.out.println("Usage: java TCPForward localPort remoteIP remotePort");
			return;
		}

		TCPForward server = new TCPForward(Integer.parseInt(args[0]),args[1],Integer.parseInt(args[2]));
		server.createServer();
/*		String sb="hello\r\n\r\nworld\r\n";
		StringReader read = new StringReader(sb);
		BufferedReader read1 = new BufferedReader(read);
		String hh=null;
		while((hh=read1.readLine())!=null){
		  if(hh.equalsIgnoreCase("\n"))
		  System.out.print(hh+"gg\r\n");
		}
		System.out.println(Character.isSpaceChar(' '));
		*/
	  }
}

class Worker extends Thread{
	public void run(){
	   http();
	}

	Socket socket = null;
	static public boolean logging = false;
	public OutputStream log=null;
	static public int CONNECT_RETRIES=3;
	static public int CONNECT_PAUSE=3;
	static public int TIMEOUT=50;
	static public int BUFSIZ=4096;
	static public int port = 1521;
	static public String host="192.168.6.5";
	public Worker(Socket _socket,String _host,int _port,OutputStream _log){
		socket = _socket;
		port = _port;
		log = _log;
		host = _host;
	}
  public void writeLog(int c, boolean browser) throws IOException {
      log.write(c);
  }
  public void writeLog(byte[] bytes,int offset, int len, boolean browser) throws IOException {
      for (int i=0;i<len;i++) writeLog((int)bytes[offset+i],browser);
  }
  void pipe(InputStream is0, InputStream is1,OutputStream os0,  OutputStream os1) throws IOException {
       try {
           int ir;
           byte bytes[]=new byte[BUFSIZ];
           while (true) {
               try {
                   if ((ir=is0.read(bytes))>0) {
                       os0.write(bytes,0,ir);
                       if (logging) writeLog(bytes,0,ir,true);
                   }else if (ir<0)
                       break;
               } catch (InterruptedIOException e) { }
               try {
                   if ((ir=is1.read(bytes))>0) {
                       os1.write(bytes,0,ir);
                       if (logging) writeLog(bytes,0,ir,false);
                   }else if (ir<0)
                       break;
               } catch (InterruptedIOException e) {}
               if(socket.isClosed()||(!socket.isConnected())||socket.isInputShutdown()||socket.isOutputShutdown()) break;
           }
       } catch (Exception e0) {
           System.out.println("Pipe异常: " + e0);
       }
   }
   public void http(){
		Socket outbound=null;
		try {
			socket.setSoTimeout(TIMEOUT);
			InputStream is=socket.getInputStream();
			OutputStream os=null;
			try {
			   // 获取请求行的内容
				int state=0;
				boolean space;
				int retry=CONNECT_RETRIES;
				while (retry--!=0) {
				   try {
					   outbound=new Socket(host,port);
					   break;
				   } catch (Exception e) { e.printStackTrace();}
				   // 等待
				   Thread.sleep(CONNECT_PAUSE);
				}
				if (outbound==null) return;
				outbound.setSoTimeout(TIMEOUT);
				os=outbound.getOutputStream();
				pipe(is,outbound.getInputStream(),os,socket.getOutputStream());
			}catch (IOException e) { e.printStackTrace(); }
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
		   try { socket.close();System.out.println("socket close");} catch (Exception e1) {e1.printStackTrace();}
		   try { outbound.close();} catch (Exception e2) {e2.printStackTrace();}
		}
 }
 

}
