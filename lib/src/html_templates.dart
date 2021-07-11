part of shelf_virtual_directory;

String _listDirhtmlStart(String heading, String requestedPath) => '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$heading/</title>
    <style>
      h1 {
        width: 100%;
        font-size: 20px;
        background-color: #4361ee;
        color: #edf2fb;
        padding-top: 10px;
        padding-bottom: 10px;
        padding-left: 5px;
        padding-right: 5px;
      }
      li {
        font-size: 18px;
      }
      ul {
        display: block;
        list-style-type: disc;
        margin-block-start: 5px;
        margin-block-end: 5px;
        margin-inline-start: 0px;
        margin-inline-end: 0px;
        padding-inline-start: 10px;
      }
      .container {
        display: flex;
        flex-direction: column;
        justify-content: center;
      }
      /*mobile*/
      @media screen and (max-width: 450px) {
        .container {
          width: 90%;
          padding-left: 5%;
          padding-right: 5%;
        }
      }
      /*tablet*/
      @media screen and (min-width: 451px) and (max-width: 700px) {
        .container {
          width: 90%;
          padding-left: 5%;
          padding-right: 5%;
        }
      }
      /*PC*/
      @media screen and (min-width: 701px) and (max-width: 900px) {
        .container {
          width: 80%;
          padding-left: 10%;
          padding-right: 10%;
        }
      }
      @media screen and (min-width: 900px) {
        .container {
          width: 80%;
          padding-left: 10%;
          padding-right: 10%;
        }
      }
      table {
        border-collapse: collapse;
      }
      td,
      th {
        border: none;
        text-align: left;
        padding: 8px;
      }

      tr:nth-child(even) {
        background-color: #dddddd;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>📁$requestedPath</h1>
      <table>
        <tr>
          <th>Name</th>
          <th>Modified</th>
          <th>Permission</th>
          <th>Size</th>
        </tr>
''';

String _tableEnd() => '</table>';

String _listDirHtmlEnd() => '''
      <div>
        <a href="https://pub.dev/packages/shelf_virtual_directory">shelf_virtual_directory</a>
      </div>
    </div>
  </body>
</html>

''';
